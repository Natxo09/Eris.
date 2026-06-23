//
//  IntentUtils.swift
//  Eris.
//
//  Created by Assistant on 28/6/25.
//

import Foundation
import SwiftData

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
    static func selectModel(requestedName: String?) -> Result<AIModel, IntentError> {
        let modelManager = ModelManager.shared

        if let requestedModel = requestedName, !requestedModel.isEmpty {
            let needle = requestedModel.lowercased()
            // Match by display name (e.g. "Apple", "Qwen") or MLX repo name.
            if let model = AIModelsRegistry.shared.allModels.first(where: { model in
                if model.displayName.lowercased().contains(needle) { return true }
                if let name = model.mlxConfiguration?.name.lowercased() {
                    return name.contains(needle)
                        || name.replacingOccurrences(of: "mlx-community/", with: "").contains(needle)
                }
                return false
            }) {
                // Check if model is ready to use (downloaded, or always-on for system models)
                if modelManager.isReady(model) {
                    return .success(model)
                } else {
                    return .failure(.modelNotDownloaded(requestedModel))
                }
            } else {
                return .failure(.modelNotFound(requestedModel))
            }
        } else {
            // Use the active model
            if let activeModel = modelManager.activeAIModel {
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
        model: AIModel,
        systemPrompt: String
    ) async -> String {
        let modelManager = ModelManager.shared

        // Temporarily set the active model if using a different one
        let originalModel = modelManager.activeAIModel
        if originalModel?.id != model.id {
            modelManager.setActive(model)
        }

        // Use the shared chat engine runner for better performance
        let response = await sharedRunner.generate(
            thread: thread,
            systemPrompt: systemPrompt
        )

        // Restore original model if changed
        if originalModel?.id != model.id, let original = originalModel {
            modelManager.setActive(original)
        }

        return response
    }

    /// Returns a list of ready-to-use model names for shortcuts
    static func getAvailableModelNames() -> [String] {
        let modelManager = ModelManager.shared
        return AIModelsRegistry.shared.allModels
            .filter { modelManager.isReady($0) }
            .map { model in
                model.mlxConfiguration?.name.replacingOccurrences(of: "mlx-community/", with: "") ?? model.displayName
            }
    }
}