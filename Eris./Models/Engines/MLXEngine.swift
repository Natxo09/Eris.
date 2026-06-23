//
//  MLXEngine.swift
//  Eris.
//
//  MLX-backed `ChatEngine`. This is the former `LLMEvaluator`, with its inference
//  logic kept intact (DEV-597). UI state is now reported through `ChatEngineDelegate`
//  instead of `@Published` properties so the engine can sit behind the `ChatEngine`
//  abstraction.
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
final class CancellationToken {
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
final class MLXEngine: ChatEngine {
    private let generateParameters = GenerateParameters(maxTokens: 2048, temperature: 0.7)
    private let cancellationToken = CancellationToken()

    /// Set for the duration of a `generate` call so the loading phase can report progress.
    private weak var delegate: ChatEngineDelegate?

    enum LoadState {
        case idle
        case loading
        case loaded(ModelContainer)
        case failed(Error)
    }

    var loadState = LoadState.idle

    func cancel() {
        cancellationToken.cancel()
    }

    func load() async throws -> ModelContainer {
        guard let modelConfiguration = ModelManager.shared.activeModel else {
            throw NSError(domain: "MLXEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "No model selected"])
        }
        switch loadState {
        case .idle, .failed:
            loadState = .loading
            delegate?.chatEngine(self, didChangeLoadingState: true)

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
                        self.delegate?.chatEngine(self, didUpdateDownloadProgress: progress.fractionCompleted)
                    }
                }

                loadState = .loaded(modelContainer)
                delegate?.chatEngine(self, didChangeLoadingState: false)

                // After successful load, adjust cache based on device
                let runtimeCacheLimit = getCacheLimitForDevice()
                MLX.Memory.cacheLimit = runtimeCacheLimit
                print("Runtime cache limit adjusted to: \(runtimeCacheLimit / 1024 / 1024)MB")

                return modelContainer

            } catch {
                loadState = .failed(error)
                delegate?.chatEngine(self, didChangeLoadingState: false)

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
        case .a16, .a17Pro, .a18, .a18Pro, .a19, .a19Pro:
            // iPhone 14 Pro, 15, 16, 17 series - 6-12GB RAM devices
            baseCacheSize = 256
        case .m1, .m2, .m3, .m4, .m5:
            // iPad with M chips - 8GB+ RAM
            baseCacheSize = 512
        default:
            // Conservative default
            baseCacheSize = 32
        }

        return baseCacheSize * 1024 * 1024
    }

    func generate(thread: Thread, systemPrompt: String, delegate: ChatEngineDelegate) async -> String {
        self.delegate = delegate
        cancellationToken.reset()

        var output = ""
        var tokensGenerated = 0

        do {
            // Reflect the initial loading state to the delegate
            switch loadState {
            case .idle, .failed, .loading:
                delegate.chatEngine(self, didChangeLoadingState: true)
            case .loaded:
                delegate.chatEngine(self, didChangeLoadingState: false)
            }

            let modelContainer = try await load()
            delegate.chatEngine(self, didChangeLoadingState: false)

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

            for await generation in stream {
                if cancellationToken.isCancelled { break }
                switch generation {
                case .chunk(let text):
                    output += text
                    tokensGenerated += 1
                    delegate.chatEngine(self, didProduceOutput: output, tokenCount: tokensGenerated)
                case .info, .toolCall:
                    break
                }
            }

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

            delegate.chatEngine(self, didProduceOutput: output, tokenCount: tokensGenerated)
            print("❌ Generation error: \(error)")
        }

        self.delegate = nil
        return output
    }
}
