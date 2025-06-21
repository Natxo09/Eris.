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
import SwiftUI

// Custom error types for better error handling
enum ModelDownloadError: LocalizedError {
    case requiresWiFi
    case downloadFailed(String)
    case networkUnavailable
    
    var errorDescription: String? {
        switch self {
        case .requiresWiFi:
            return "Model downloads require a Wi-Fi connection. The MLX framework doesn't support downloading over cellular data.\n\nPlease connect to Wi-Fi to download. Once downloaded, you can use the app offline or with any connection type."
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        case .networkUnavailable:
            return "No internet connection available."
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
        if let modelName = userDefaults.string(forKey: activeModelKey),
           let aiModel = AIModelsRegistry.shared.modelByName(modelName) {
            activeModel = aiModel.configuration
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
    
    func downloadModel(_ model: ModelConfiguration, progressHandler: @escaping (Progress) -> Void) async throws {
        print("Starting download for model: \(model.name)")
        
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
        MLX.GPU.set(cacheLimit: cacheLimit)
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
        userDefaults.removeObject(forKey: activeModelKey)
        
        // Delete all model files
        for aiModel in AIModelsRegistry.shared.allModels {
            deleteModelFiles(for: aiModel.configuration)
        }
    }
    
    private func deleteModelFiles(for model: ModelConfiguration) {
        let fileManager = FileManager.default
        
        // Try to find and delete model files in Documents/huggingface
        if let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let modelPath = documentsPath
                .appendingPathComponent("huggingface")
                .appendingPathComponent("models")
                .appendingPathComponent(model.name)
            
            do {
                if fileManager.fileExists(atPath: modelPath.path) {
                    try fileManager.removeItem(at: modelPath)
                    print("Deleted model files at: \(modelPath)")
                }
            } catch {
                print("Error deleting model files: \(error)")
            }
        }
    }
}