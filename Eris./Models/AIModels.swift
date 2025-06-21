//
//  AIModels.swift
//  Eris.
//
//  Created by Assistant on 21/6/25.
//

import Foundation
import MLXLMCommon
import SwiftUI

// MARK: - Model Category
enum ModelCategory: String, CaseIterable {
    case general = "General Purpose"
    case reasoning = "Reasoning"
    case code = "Code"
    
    var icon: String {
        switch self {
        case .general: return "cpu"
        case .reasoning: return "brain"
        case .code: return "chevron.left.forwardslash.chevron.right"
        }
    }
    
    var description: String {
        switch self {
        case .general: return "Versatile models for everyday conversations"
        case .reasoning: return "Advanced models optimized for complex reasoning"
        case .code: return "Specialized models for programming tasks"
        }
    }
}

// MARK: - Model Compatibility
enum ModelCompatibility {
    case recommended
    case compatible
    case risky
    case notRecommended
    
    var description: String {
        switch self {
        case .recommended: return "Recommended for your device"
        case .compatible: return "Compatible with your device"
        case .risky: return "May experience issues"
        case .notRecommended: return "Not recommended - High crash risk"
        }
    }
    
    var icon: String {
        switch self {
        case .recommended: return "checkmark.circle.fill"
        case .compatible: return "checkmark.circle"
        case .risky: return "exclamationmark.triangle.fill"
        case .notRecommended: return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .recommended: return .green
        case .compatible: return .blue
        case .risky: return .orange
        case .notRecommended: return .red
        }
    }
}

// MARK: - AI Model
struct AIModel: Identifiable {
    let id: String
    let configuration: ModelConfiguration
    let category: ModelCategory
    let displayName: String
    let description: String
    let estimatedRAMUsage: Int // in MB
    let minimumChipRequired: DeviceUtils.ChipFamily
    let parameterCount: String // e.g., "1B", "3.5B"
    let quantization: String // e.g., "4-bit", "8-bit"
    
    var fullName: String {
        configuration.name
    }
    
    var shortName: String {
        displayName
    }
}

// MARK: - AI Models Registry
class AIModelsRegistry {
    static let shared = AIModelsRegistry()
    
    private init() {}
    
    // MARK: - Model Definitions
    private let models: [AIModel] = [
        // General Purpose Models
        AIModel(
            id: "llama3_2_1B",
            configuration: ModelConfiguration(id: "mlx-community/Llama-3.2-1B-Instruct-4bit"),
            category: .general,
            displayName: "Llama 3.2 1B",
            description: "Meta's efficient model, great for everyday conversations",
            estimatedRAMUsage: 800,
            minimumChipRequired: .a13,
            parameterCount: "1B",
            quantization: "4-bit"
        ),
        AIModel(
            id: "llama3_2_3B",
            configuration: ModelConfiguration(id: "mlx-community/Llama-3.2-3B-Instruct-4bit"),
            category: .general,
            displayName: "Llama 3.2 3B",
            description: "Larger Llama model with enhanced capabilities",
            estimatedRAMUsage: 2400,
            minimumChipRequired: .a15,
            parameterCount: "3B",
            quantization: "4-bit"
        ),
        AIModel(
            id: "qwen2_5_0_5B",
            configuration: ModelConfiguration(id: "mlx-community/Qwen2.5-0.5B-Instruct-4bit"),
            category: .general,
            displayName: "Qwen 2.5 0.5B",
            description: "Ultra-lightweight multilingual model",
            estimatedRAMUsage: 400,
            minimumChipRequired: .a13,
            parameterCount: "0.5B",
            quantization: "4-bit"
        ),
        AIModel(
            id: "qwen2_5_1_5B",
            configuration: ModelConfiguration(id: "mlx-community/Qwen2.5-1.5B-Instruct-4bit"),
            category: .general,
            displayName: "Qwen 2.5 1.5B",
            description: "Balanced multilingual model from Alibaba",
            estimatedRAMUsage: 1200,
            minimumChipRequired: .a13,
            parameterCount: "1.5B",
            quantization: "4-bit"
        ),
        AIModel(
            id: "qwen2_5_3B",
            configuration: ModelConfiguration(id: "mlx-community/Qwen2.5-3B-Instruct-4bit"),
            category: .general,
            displayName: "Qwen 2.5 3B",
            description: "Advanced multilingual capabilities",
            estimatedRAMUsage: 2400,
            minimumChipRequired: .a15,
            parameterCount: "3B",
            quantization: "4-bit"
        ),
        AIModel(
            id: "gemma2_2B",
            configuration: ModelConfiguration(id: "mlx-community/gemma-2-2b-it-4bit"),
            category: .general,
            displayName: "Gemma 2 2B",
            description: "Google's lightweight model with strong performance",
            estimatedRAMUsage: 1600,
            minimumChipRequired: .a14,
            parameterCount: "2B",
            quantization: "4-bit"
        ),
        AIModel(
            id: "phi3_5Mini",
            configuration: ModelConfiguration(id: "mlx-community/Phi-3.5-mini-instruct-4bit"),
            category: .general,
            displayName: "Phi 3.5 Mini",
            description: "Microsoft's compact yet capable model",
            estimatedRAMUsage: 2800,
            minimumChipRequired: .a15,
            parameterCount: "3.8B",
            quantization: "4-bit"
        ),
        AIModel(
            id: "mistral7B",
            configuration: ModelConfiguration(id: "mlx-community/Mistral-7B-Instruct-v0.3-4bit"),
            category: .general,
            displayName: "Mistral 7B",
            description: "Popular open-source model with excellent performance",
            estimatedRAMUsage: 5600,
            minimumChipRequired: .a16,
            parameterCount: "7B",
            quantization: "4-bit"
        ),
        
        // Reasoning Models
        AIModel(
            id: "deepseekR1_1_5B_4bit",
            configuration: ModelConfiguration(id: "mlx-community/DeepSeek-R1-Distill-Qwen-1.5B-4bit"),
            category: .reasoning,
            displayName: "DeepSeek R1 1.5B (4-bit)",
            description: "Advanced reasoning with efficient quantization",
            estimatedRAMUsage: 1200,
            minimumChipRequired: .a14,
            parameterCount: "1.5B",
            quantization: "4-bit"
        ),
        AIModel(
            id: "deepseekR1_1_5B_8bit",
            configuration: ModelConfiguration(id: "mlx-community/DeepSeek-R1-Distill-Qwen-1.5B-8bit"),
            category: .reasoning,
            displayName: "DeepSeek R1 1.5B (8-bit)",
            description: "Higher precision reasoning model",
            estimatedRAMUsage: 2400,
            minimumChipRequired: .a15,
            parameterCount: "1.5B",
            quantization: "8-bit"
        ),
        
        // Code Models
        AIModel(
            id: "codeLlama7B",
            configuration: ModelConfiguration(id: "mlx-community/CodeLlama-7b-Instruct-hf-4bit"),
            category: .code,
            displayName: "CodeLlama 7B",
            description: "Meta's specialized model for programming",
            estimatedRAMUsage: 5600,
            minimumChipRequired: .a16,
            parameterCount: "7B",
            quantization: "4-bit"
        ),
        AIModel(
            id: "stableCode3B",
            configuration: ModelConfiguration(id: "mlx-community/stable-code-instruct-3b-4bit"),
            category: .code,
            displayName: "StableCode 3B",
            description: "Efficient code generation and completion",
            estimatedRAMUsage: 2400,
            minimumChipRequired: .a15,
            parameterCount: "3B",
            quantization: "4-bit"
        )
    ]
    
    // MARK: - Public API
    var allModels: [AIModel] {
        models
    }
    
    var categorizedModels: [ModelCategory: [AIModel]] {
        Dictionary(grouping: models, by: { $0.category })
    }
    
    var defaultModel: AIModel {
        models.first { $0.id == "llama3_2_1B" } ?? models[0]
    }
    
    func modelByConfiguration(_ configuration: ModelConfiguration) -> AIModel? {
        models.first { $0.configuration.name == configuration.name }
    }
    
    func modelByName(_ name: String) -> AIModel? {
        models.first { $0.configuration.name == name }
    }
    
    func modelById(_ id: String) -> AIModel? {
        models.first { $0.id == id }
    }
    
    // MARK: - Compatibility
    func compatibilityForModel(_ model: AIModel) -> ModelCompatibility {
        let chipFamily = DeviceUtils.chipFamily
        let deviceRAM = DeviceUtils.estimatedRAM
        
        // Check if chip meets minimum requirement
        guard chipFamily.rawValue >= model.minimumChipRequired.rawValue else {
            return .notRecommended
        }
        
        // Check RAM requirements with safety margin (2x model size + 2GB for system)
        let requiredRAM = (model.estimatedRAMUsage * 2) + 2000
        
        if deviceRAM >= requiredRAM + 1000 { // 1GB extra margin
            return .recommended
        } else if deviceRAM >= requiredRAM {
            return .compatible
        } else if deviceRAM >= model.estimatedRAMUsage + 2000 {
            return .risky
        } else {
            return .notRecommended
        }
    }
    
    func recommendedModelsForDevice() -> [AIModel] {
        models.filter { model in
            let compatibility = compatibilityForModel(model)
            return compatibility == .recommended || compatibility == .compatible
        }.sorted { model1, model2 in
            // Sort by compatibility first, then by RAM usage
            let comp1 = compatibilityForModel(model1)
            let comp2 = compatibilityForModel(model2)
            
            if comp1 == comp2 {
                return model1.estimatedRAMUsage < model2.estimatedRAMUsage
            }
            
            // Recommended > Compatible
            return comp1 == .recommended && comp2 != .recommended
        }
    }
    
    func modelsForCategory(_ category: ModelCategory) -> [AIModel] {
        models.filter { $0.category == category }
    }
}

// MARK: - Extensions for backward compatibility
extension ModelConfiguration {
    static var availableModels: [ModelConfiguration] {
        AIModelsRegistry.shared.allModels.map { $0.configuration }
    }
    
    static var defaultModel: ModelConfiguration {
        AIModelsRegistry.shared.defaultModel.configuration
    }
    
    static func getModelByName(_ name: String) -> ModelConfiguration? {
        AIModelsRegistry.shared.modelByName(name)?.configuration
    }
}

// MARK: - Device Utils Extension
extension DeviceUtils {
    static var estimatedRAM: Int {
        // Estimated RAM in MB based on chip family
        switch chipFamily {
        case .a13, .a14:
            return 4096  // 4GB
        case .a15:
            return 6144  // 6GB
        case .a16:
            return 6144  // 6GB
        case .a17Pro:
            return 8192  // 8GB
        case .a18, .a18Pro:
            return 8192  // 8GB
        case .m1, .m2:
            return 8192  // 8GB minimum
        case .m3, .m4:
            return 16384 // 16GB minimum
        default:
            return 4096  // Conservative estimate
        }
    }
}