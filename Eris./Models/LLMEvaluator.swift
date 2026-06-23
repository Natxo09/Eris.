//
//  LLMEvaluator.swift
//  Eris.
//
//  Created by Ignacio Palacio on 19/6/25.
//

import MLX
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import MLXRandom
import HuggingFace
import Tokenizers
import SwiftUI

// Helper class to manage cancellation state across actor boundaries
class CancellationToken {
    private var _isCancelled = false
    private let lock = NSLock()
    
    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isCancelled
    }
    
    func cancel() {
        lock.lock()
        defer { lock.unlock() }
        _isCancelled = true
    }
    
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        _isCancelled = false
    }
}

@MainActor
class LLMEvaluator: ObservableObject {
    @Published var running = false
    @Published var isLoadingModel = false
    @Published var output = ""
    @Published var modelInfo = ""
    @Published var progress = 0.0
    @Published var tokensGenerated = 0
    
    private var modelConfiguration: ModelConfiguration?
    private let generateParameters = GenerateParameters(maxTokens: 2048, temperature: 0.7)
    private let cancellationToken = CancellationToken()
    
    enum LoadState {
        case idle
        case loading
        case loaded(ModelContainer)
        case failed(Error)
    }
    
    var loadState = LoadState.idle
    
    func load() async throws -> ModelContainer {
        guard let modelConfiguration = ModelManager.shared.activeModel else {
            throw NSError(domain: "LLMEvaluator", code: 1, userInfo: [NSLocalizedDescriptionKey: "No model selected"])
        }
        switch loadState {
        case .idle, .failed:
            loadState = .loading
            isLoadingModel = true
            
            // Use conservative cache limit during model loading
            // Similar to Fullmoon's approach for better stability
            let cacheLimit = 20 * 1024 * 1024 // 20MB during initial load
            MLX.Memory.cacheLimit = cacheLimit
            print("GPU cache limit set to: \(cacheLimit / 1024 / 1024)MB for model loading")
            
            do {
                // For low-memory devices, use compatibility mode
                if DeviceUtils.chipFamily == .a13 || DeviceUtils.chipFamily == .a14 {
                    print("⏳ Using compatibility mode for limited memory device...")
                    
                    // Force memory cleanup
                    MemoryManager.shared.performLowMemoryCleanup()
                    
                    // Wait for system to stabilize
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    
                    // Set minimal cache
                    MLX.Memory.cacheLimit = 16 * 1024 * 1024 // 16MB minimum
                }
                
                let modelContainer = try await LLMModelFactory.shared.loadContainer(
                    from: #hubDownloader(),
                    using: #huggingFaceTokenizerLoader(),
                    configuration: modelConfiguration
                ) { progress in
                    Task { @MainActor in
                        self.modelInfo = "Downloading: \(Int(progress.fractionCompleted * 100))%"
                        self.progress = progress.fractionCompleted
                    }
                }
                
                modelInfo = "Model loaded successfully"
                loadState = .loaded(modelContainer)
                isLoadingModel = false
                
                // After successful load, adjust cache based on device
                let runtimeCacheLimit = getCacheLimitForDevice()
                MLX.Memory.cacheLimit = runtimeCacheLimit
                print("Runtime cache limit adjusted to: \(runtimeCacheLimit / 1024 / 1024)MB")
                
                return modelContainer
                
            } catch {
                loadState = .failed(error)
                isLoadingModel = false
                
                // Log detailed error information
                print("❌ Failed to load model: \(error)")
                
                // Check if it's a Metal compilation error
                let errorDescription = error.localizedDescription.lowercased()
                if errorDescription.contains("metal") || errorDescription.contains("kernel") || errorDescription.contains("xpc_error") {
                    print("⚠️ Metal compilation error detected. This may be due to memory constraints.")
                    print("💡 Try closing other apps and restarting the device.")
                }
                
                throw error
            }
            
        case .loading:
            // Wait for current load
            while case .loading = loadState {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
            return try await load()
            
        case let .loaded(modelContainer):
            return modelContainer
        }
    }
    
    func stopGeneration() {
        cancellationToken.cancel()
    }
    
    private func getCacheLimitForDevice() -> Int {
        // Get device info
        let chipFamily = DeviceUtils.chipFamily
        
        // Base cache sizes in MB
        let baseCacheSize: Int
        
        switch chipFamily {
        case .a13, .a14:
            // iPhone 11, 12 series - 4GB RAM devices
            baseCacheSize = 64
        case .a15:
            // iPhone 13, 14 series - 6GB RAM devices
            baseCacheSize = 128
        case .a16, .a17Pro, .a18, .a18Pro:
            // iPhone 14 Pro, 15, 16 series - 6-8GB RAM devices
            baseCacheSize = 256
        case .m1, .m2, .m3, .m4:
            // iPad with M chips - 8GB+ RAM
            baseCacheSize = 512
        default:
            // Conservative default
            baseCacheSize = 32
        }
        
        return baseCacheSize * 1024 * 1024
    }
    
    func generate(thread: Thread, systemPrompt: String = "You are a helpful assistant.") async -> String {
        guard !running else { return "" }
        
        running = true
        output = ""
        tokensGenerated = 0
        cancellationToken.reset()
        
        do {
            // Check if model needs to be loaded
            switch loadState {
            case .idle, .failed:
                isLoadingModel = true
            case .loading:
                isLoadingModel = true
            case .loaded:
                isLoadingModel = false
            }
            
            let modelContainer = try await load()
            isLoadingModel = false
            
            // Build the structured chat history (system prompt + conversation)
            var chat: [Chat.Message] = [.system(systemPrompt)]
            for message in thread.sortedMessages {
                switch message.role {
                case .user:
                    chat.append(.user(message.content))
                case .assistant:
                    chat.append(.assistant(message.content))
                case .system:
                    chat.append(.system(message.content))
                }
            }

            // Generate random seed
            MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))

            // Prepare input and stream the generation (mlx-swift-lm 3.x AsyncStream API)
            let lmInput = try await modelContainer.prepare(input: UserInput(chat: chat))
            let stream = try await modelContainer.generate(
                input: lmInput,
                parameters: generateParameters
            )

            var generatedText = ""
            for await generation in stream {
                if cancellationToken.isCancelled { break }
                switch generation {
                case .chunk(let text):
                    generatedText += text
                    output = generatedText
                    tokensGenerated += 1
                case .info, .toolCall:
                    break
                }
            }

            output = generatedText
            
        } catch {
            // Provide more helpful error messages
            let errorDescription = error.localizedDescription.lowercased()
            
            if errorDescription.contains("metal") || errorDescription.contains("kernel") || errorDescription.contains("xpc_error") {
                output = "Error: Unable to load model due to memory constraints. Please try:\n1. Close other apps\n2. Restart your device\n3. Try a smaller model (0.5B or 1B)"
            } else if errorDescription.contains("memory") {
                output = "Error: Out of memory. Please close other apps and try again."
            } else {
                output = "Error: \(error.localizedDescription)"
            }
            
            print("❌ Generation error: \(error)")
        }
        
        running = false
        return output
    }
}