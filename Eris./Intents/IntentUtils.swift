//
//  IntentUtils.swift
//  Eris.
//
//  Created by Assistant on 28/6/25.
//

import Foundation
import SwiftData
import MLXLMCommon

enum IntentError: LocalizedError {
    case modelNotDownloaded(String)
    case modelNotFound(String)
    case noModelSelected
    
    var errorDescription: String? {
        switch self {
        case .modelNotDownloaded(let name):
            return "Model '\(name)' is not downloaded. Please download it in the app first."
        case .modelNotFound(let name):
            return "Model '\(name)' not found. Please check the model name."
        case .noModelSelected:
            return "No AI model selected. Please open Eris and download a model first."
        }
    }
}

@available(iOS 16.0, *)
@MainActor
struct IntentUtils {
    // Shared chat engine runner for all intents to improve performance
    static let sharedRunner = ChatEngineRunner()
    
    /// Selects the appropriate model based on user input or defaults to active model
    static func selectModel(requestedName: String?) -> Result<MLXLMCommon.ModelConfiguration, IntentError> {
        let modelManager = ModelManager.shared
        
        if let requestedModel = requestedName, !requestedModel.isEmpty {
            // Try to find the requested model
            if let model = MLXLMCommon.ModelConfiguration.availableModels.first(where: { 
                $0.name.lowercased().contains(requestedModel.lowercased()) ||
                $0.name.replacingOccurrences(of: "mlx-community/", with: "").lowercased().contains(requestedModel.lowercased())
            }) {
                // Check if model is downloaded
                if modelManager.isModelDownloaded(model) {
                    return .success(model)
                } else {
                    return .failure(.modelNotDownloaded(requestedModel))
                }
            } else {
                return .failure(.modelNotFound(requestedModel))
            }
        } else {
            // Use the active model
            if let activeModel = modelManager.activeModel {
                return .success(activeModel)
            } else {
                return .failure(.noModelSelected)
            }
        }
    }
    
    /// Saves a thread to the database if requested
    static func saveThreadIfNeeded(_ thread: Thread, saveChat: Bool) {
        guard saveChat else { return }
        
        Task { @MainActor in
            do {
                // Create a new model container for saving
                let modelContainer = try ModelContainer(for: Thread.self, Message.self)
                modelContainer.mainContext.insert(thread)
                try modelContainer.mainContext.save()
            } catch {
                print("Failed to save chat: \(error)")
            }
        }
    }
    
    /// Generates a response using the specified model
    static func generateResponse(
        thread: Thread,
        model: MLXLMCommon.ModelConfiguration,
        systemPrompt: String
    ) async -> String {
        let modelManager = ModelManager.shared
        
        // Temporarily set the active model if using a different one
        let originalModel = modelManager.activeModel
        if model != originalModel {
            modelManager.setActiveModel(model)
        }
        
        // Use the shared chat engine runner for better performance
        let response = await sharedRunner.generate(
            thread: thread,
            systemPrompt: systemPrompt
        )
        
        // Restore original model if changed
        if model != originalModel, let original = originalModel {
            modelManager.setActiveModel(original)
        }
        
        return response
    }
    
    /// Returns a list of downloaded model names for shortcuts
    static func getAvailableModelNames() -> [String] {
        let modelManager = ModelManager.shared
        return MLXLMCommon.ModelConfiguration.availableModels
            .filter { modelManager.isModelDownloaded($0) }
            .map { $0.name.replacingOccurrences(of: "mlx-community/", with: "") }
    }
}