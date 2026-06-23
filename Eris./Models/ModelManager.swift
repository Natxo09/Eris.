//
//  ModelManager.swift
//  Eris.
//
//  Created by Ignacio Palacio on 19/6/25.
//

import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import HuggingFace
import Tokenizers
import SwiftUI

// Custom error types for better error handling
enum ModelDownloadError: LocalizedError {
    case requiresWiFi
    case downloadFailed(String)
    case networkUnavailable
    case unsupportedModelType(String)
    case modelNotFound(String)
    case configurationError(String)
    
    var errorDescription: String? {
        switch self {
        case .requiresWiFi:
            return "Model downloads require a Wi-Fi connection. The MLX framework doesn't support downloading over cellular data.\n\nPlease connect to Wi-Fi to download. Once downloaded, you can use the app offline or with any connection type."
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        case .networkUnavailable:
            return "No internet connection available."
        case .unsupportedModelType(let type):
            return "This model uses '\(type)' architecture which is not supported by MLX framework. Please choose a different model."
        case .modelNotFound(let name):
            return "Model '\(name)' could not be found or accessed. It may have been moved or removed from the repository."
        case .configurationError(let details):
            return "Model configuration error: \(details)"
        }
    }
}

@MainActor
class ModelManager: ObservableObject {
    @Published var downloadedModels: Set<String> = []
    @Published var activeModel: ModelConfiguration?
    @Published var activeAIModel: AIModel?
    @Published var downloadingModels: Set<String> = []
    @Published var downloadProgress: [String: Double] = [:]
    
    private let userDefaults = UserDefaults.standard
    private let downloadedModelsKey = "downloadedModels"
    private let activeModelKey = "activeModel"
    
    static let shared = ModelManager()
    
    init() {
        loadDownloadedModels()
        loadActiveModel()
    }
    
    private func loadDownloadedModels() {
        if let saved = userDefaults.stringArray(forKey: downloadedModelsKey) {
            downloadedModels = Set(saved)
        }
    }
    
    private func loadActiveModel() {
        guard let storedKey = userDefaults.string(forKey: activeModelKey) else { return }
        // Stored value is the MLX repo name for MLX models, or the model id for
        // sources without a configuration (e.g. Apple Foundation, DEV-598).
        if let aiModel = AIModelsRegistry.shared.modelByName(storedKey)
            ?? AIModelsRegistry.shared.modelById(storedKey) {
            activeModel = aiModel.mlxConfiguration
            activeAIModel = aiModel
        }
    }
    
    private func saveDownloadedModels() {
        userDefaults.set(Array(downloadedModels), forKey: downloadedModelsKey)
    }
    
    func isModelDownloaded(_ model: ModelConfiguration) -> Bool {
        downloadedModels.contains(model.name)
    }
    
    func setActiveModel(_ model: ModelConfiguration) {
        activeModel = model
        activeAIModel = AIModelsRegistry.shared.modelByConfiguration(model)
        userDefaults.set(model.name, forKey: activeModelKey)
    }
    
    private func validateModel(_ model: ModelConfiguration) throws {
        // List of known unsupported model types
        let unsupportedModelTypes = ["stablelm", "stablecode"]
        let modelNameLower = model.name.lowercased()
        
        // Check for known unsupported model types
        for unsupported in unsupportedModelTypes {
            if modelNameLower.contains(unsupported) {
                throw ModelDownloadError.unsupportedModelType(unsupported)
            }
        }
        
        // List of known problematic models
        let problematicModels = [
            "mlx-community/CodeLlama-7b-Instruct-hf-4bit",
            "mlx-community/stable-code-instruct-3b-4bit"
        ]
        
        if problematicModels.contains(model.name) {
            throw ModelDownloadError.modelNotFound(model.name)
        }
        
        // Validate model is in our registry
        guard AIModelsRegistry.shared.modelByConfiguration(model) != nil else {
            throw ModelDownloadError.configurationError("Model not found in registry")
        }
    }
    
    func downloadModel(_ model: ModelConfiguration, progressHandler: @escaping (Progress) -> Void) async throws {
        print("Starting download for model: \(model.name)")
        
        // Validate model before attempting download
        try validateModel(model)
        
        // Mark as downloading
        downloadingModels.insert(model.name)
        downloadProgress[model.name] = 0.0
        
        // Check network connectivity
        if !NetworkMonitor.shared.isConnected {
            throw ModelDownloadError.networkUnavailable
        }
        
        // Use lower cache limit for better compatibility with cellular connections
        // Similar to Fullmoon's approach (20MB)
        let cacheLimit = 20 * 1024 * 1024 // 20MB for all devices during download
        MLX.Memory.cacheLimit = cacheLimit
        print("Download cache limit set to: \(cacheLimit / 1024 / 1024)MB")
        
        var lastError: Error?
        let maxRetries = 3
        let baseDelay: UInt64 = 2_000_000_000 // 2 seconds in nanoseconds
        
        // Retry logic with exponential backoff
        for attempt in 0..<maxRetries {
            if attempt > 0 {
                let delay = baseDelay * UInt64(pow(2.0, Double(attempt - 1)))
                print("Retrying download after \(Double(delay) / 1_000_000_000) seconds...")
                try await Task.sleep(nanoseconds: delay)
            }
            
            do {
                // Download the model
                print("Download attempt \(attempt + 1) of \(maxRetries)")
                _ = try await LLMModelFactory.shared.loadContainer(
                    from: #hubDownloader(),
                    using: #huggingFaceTokenizerLoader(),
                    configuration: model,
                    progressHandler: { progress in
                        print("Download progress: \(progress.fractionCompleted)")
                        Task { @MainActor in
                            self.downloadProgress[model.name] = progress.fractionCompleted
                        }
                        progressHandler(progress)
                    }
                )
                
                print("Model downloaded successfully")
                
                // Mark as downloaded
                downloadedModels.insert(model.name)
                saveDownloadedModels()
                
                // If no active model, set this as active
                if activeModel == nil {
                    setActiveModel(model)
                }
                
                // Clean up download state
                downloadingModels.remove(model.name)
                downloadProgress.removeValue(forKey: model.name)
                
                return // Success, exit the function
                
            } catch {
                lastError = error
                print("Download attempt \(attempt + 1) failed: \(error)")
                
                // Check if it's the "Repository not available locally" error
                let errorMessage = error.localizedDescription.lowercased()
                let errorString = String(describing: error)
                
                if errorMessage.contains("repository not available") || 
                   errorMessage.contains("offline mode") ||
                   errorString.contains("offlineModeError") {
                    // This is a known MLX framework limitation on cellular
                    print("MLX Framework entered offline mode on cellular connection")
                    // Clean up download state
                    downloadingModels.remove(model.name)
                    downloadProgress.removeValue(forKey: model.name)
                    throw ModelDownloadError.requiresWiFi
                }
                
                // Check for unsupported model type errors
                if errorMessage.contains("unsupported model type") || errorString.contains("stablelm") {
                    let modelType = errorString.components(separatedBy: "\"").dropFirst().first ?? "unknown"
                    print("Unsupported model type detected: \(modelType)")
                    // Clean up download state
                    downloadingModels.remove(model.name)
                    downloadProgress.removeValue(forKey: model.name)
                    throw ModelDownloadError.unsupportedModelType(modelType)
                }
                
                // Check for missing config.json or model not found errors
                if errorMessage.contains("config.json") || errorMessage.contains("couldn't be opened") ||
                   errorMessage.contains("not found") || errorMessage.contains("404") {
                    print("Model not found or configuration missing")
                    // Clean up download state
                    downloadingModels.remove(model.name)
                    downloadProgress.removeValue(forKey: model.name)
                    throw ModelDownloadError.modelNotFound(model.name)
                }
                
                // Check for other configuration errors
                if errorMessage.contains("configuration") || errorMessage.contains("invalid") {
                    print("Model configuration error")
                    // Clean up download state
                    downloadingModels.remove(model.name)
                    downloadProgress.removeValue(forKey: model.name)
                    throw ModelDownloadError.configurationError(errorMessage)
                }
            }
        }
        
        // All retries failed
        // Clean up download state
        downloadingModels.remove(model.name)
        downloadProgress.removeValue(forKey: model.name)
        
        if let error = lastError {
            throw ModelDownloadError.downloadFailed(error.localizedDescription)
        } else {
            throw ModelDownloadError.downloadFailed("Unknown error")
        }
    }
    
    func deleteModel(_ model: ModelConfiguration) {
        // Remove from downloaded models
        downloadedModels.remove(model.name)
        saveDownloadedModels()
        
        // If this was the active model, clear it
        if activeModel?.name == model.name {
            activeModel = nil
            activeAIModel = nil
            userDefaults.removeObject(forKey: activeModelKey)
        }

        // Try to delete model files from disk
        deleteModelFiles(for: model)
    }

    func deleteAllModels() {
        // Clear all models
        downloadedModels.removeAll()
        saveDownloadedModels()

        // Clear active model
        activeModel = nil
        activeAIModel = nil
        userDefaults.removeObject(forKey: activeModelKey)
        
        // Delete all model files
        for aiModel in AIModelsRegistry.shared.allModels {
            if let configuration = aiModel.mlxConfiguration {
                deleteModelFiles(for: configuration)
            }
        }
    }
    
    // MARK: - Source-aware API (DEV-597)
    // These operate on `AIModel` and dispatch on `ModelSource`, so callers no
    // longer need to handle MLX `ModelConfiguration` directly. Sources that are
    // not downloaded on-demand (e.g. Apple Foundation Models) are treated as
    // always-ready and their download/delete operations become no-ops.

    /// Whether the model is ready to use (downloaded for MLX, always-on for system models).
    func isReady(_ model: AIModel) -> Bool {
        switch model.source {
        case .mlx(let configuration):
            return downloadedModels.contains(configuration.name)
        case .appleFoundation:
            return true
        }
    }

    /// Whether this is the currently active model.
    func isActive(_ model: AIModel) -> Bool {
        activeAIModel?.id == model.id
    }

    /// Whether an MLX download is currently in progress for this model.
    func isDownloading(_ model: AIModel) -> Bool {
        guard case .mlx(let configuration) = model.source else { return false }
        return downloadingModels.contains(configuration.name)
    }

    /// Current download progress (`0...1`) for this model, if any.
    func downloadProgress(for model: AIModel) -> Double {
        guard case .mlx(let configuration) = model.source else { return 0 }
        return downloadProgress[configuration.name] ?? 0
    }

    /// Marks the given model as active, persisting the selection.
    func setActive(_ model: AIModel) {
        switch model.source {
        case .mlx(let configuration):
            setActiveModel(configuration)
        case .appleFoundation:
            activeModel = nil
            activeAIModel = model
            userDefaults.set(model.id, forKey: activeModelKey)
        }
    }

    /// Downloads the model if its source requires it; a no-op otherwise.
    func download(_ model: AIModel, progressHandler: @escaping (Progress) -> Void) async throws {
        switch model.source {
        case .mlx(let configuration):
            try await downloadModel(configuration, progressHandler: progressHandler)
        case .appleFoundation:
            return
        }
    }

    /// Deletes the model's local files if its source has any; a no-op otherwise.
    func delete(_ model: AIModel) {
        switch model.source {
        case .mlx(let configuration):
            deleteModel(configuration)
        case .appleFoundation:
            return
        }
    }

    private func deleteModelFiles(for model: ModelConfiguration) {
        let fileManager = FileManager.default

        // mlx-swift-lm 3.x downloads through swift-huggingface's HubClient, which caches under
        // <app>/Library/Caches/huggingface/hub/models--<namespace>--<name> on iOS. Ask the
        // library's own cache for the directory so the path always matches where the weights
        // were actually written (and keeps working if the convention changes upstream).
        if let repo = Repo.ID(rawValue: model.name) {
            let cache = HubCache.default
            let directories = [
                cache.repoDirectory(repo: repo, kind: .model),
                cache.metadataDirectory(repo: repo, kind: .model)
            ]
            for directory in directories where fileManager.fileExists(atPath: directory.path) {
                do {
                    try fileManager.removeItem(at: directory)
                    print("Deleted model files at: \(directory.path)")
                } catch {
                    print("Error deleting model files at \(directory.path): \(error)")
                }
            }
        }

        // Legacy cleanup: models downloaded by the old mlx-swift-examples HubApi lived in
        // Documents/huggingface/models/<name>. Remove those too for users upgrading from 2.x.
        if let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let legacyPath = documentsPath
                .appendingPathComponent("huggingface")
                .appendingPathComponent("models")
                .appendingPathComponent(model.name)
            if fileManager.fileExists(atPath: legacyPath.path) {
                try? fileManager.removeItem(at: legacyPath)
            }
        }
    }
}