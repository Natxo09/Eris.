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
    let source: ModelSource
    let category: ModelCategory
    let displayName: String
    let description: String
    let estimatedRAMUsage: Int // in MB
    let minimumChipRequired: DeviceUtils.ChipFamily
    let parameterCount: String // e.g., "1B", "3.5B"
    let quantization: String // e.g., "4-bit", "8-bit"
    let isLegacy: Bool // For older models kept for compatibility

    /// General initializer covering any `ModelSource`.
    init(
        id: String,
        source: ModelSource,
        category: ModelCategory,
        displayName: String,
        description: String,
        estimatedRAMUsage: Int,
        minimumChipRequired: DeviceUtils.ChipFamily,
        parameterCount: String,
        quantization: String,
        isLegacy: Bool = false
    ) {
        self.id = id
        self.source = source
        self.category = category
        self.displayName = displayName
        self.description = description
        self.estimatedRAMUsage = estimatedRAMUsage
        self.minimumChipRequired = minimumChipRequired
        self.parameterCount = parameterCount
        self.quantization = quantization
        self.isLegacy = isLegacy
    }

    /// Convenience initializer for MLX-backed models. Keeps the registry
    /// declarations unchanged while `source` becomes the source of truth.
    init(
        id: String,
        configuration: ModelConfiguration,
        category: ModelCategory,
        displayName: String,
        description: String,
        estimatedRAMUsage: Int,
        minimumChipRequired: DeviceUtils.ChipFamily,
        parameterCount: String,
        quantization: String,
        isLegacy: Bool = false
    ) {
        self.init(
            id: id,
            source: .mlx(configuration),
            category: category,
            displayName: displayName,
            description: description,
            estimatedRAMUsage: estimatedRAMUsage,
            minimumChipRequired: minimumChipRequired,
            parameterCount: parameterCount,
            quantization: quantization,
            isLegacy: isLegacy
        )
    }

    /// The MLX configuration when this model is MLX-backed, otherwise `nil`.
    var mlxConfiguration: ModelConfiguration? {
        if case .mlx(let configuration) = source { return configuration }
        return nil
    }

    /// `true` for models provisioned and managed by the OS (no download, no
    /// RAM management) — currently only Apple Foundation Models.
    var isSystemManaged: Bool {
        if case .appleFoundation = source { return true }
        return false
    }
}

// MARK: - AI Models Registry
class AIModelsRegistry {
    static let shared = AIModelsRegistry()

    private init() {}

    // MARK: - Model Definitions
    private let models: [AIModel] = [
        // ============================================
        // GENERAL PURPOSE MODELS (Updated 2026)
        // ============================================

        // --- Qwen3 / Qwen3.5 Series (Recommended) ---
        AIModel(
            id: "qwen3_0_6B",
            configuration: ModelConfiguration(id: "mlx-community/Qwen3-0.6B-4bit"),
            category: .general,
            displayName: "Qwen3 0.6B",
            description: "Ultra-lightweight multilingual model with thinking capabilities",
            estimatedRAMUsage: 400,
            minimumChipRequired: .a13,
            parameterCount: "0.6B",
            quantization: "4-bit"
        ),
        AIModel(
            id: "qwen3_5_0_8B",
            configuration: ModelConfiguration(id: "mlx-community/Qwen3.5-0.8B-4bit"),
            category: .general,
            displayName: "Qwen3.5 0.8B",
            description: "Newest ultra-light Qwen, thinking and non-thinking modes",
            estimatedRAMUsage: 750,
            minimumChipRequired: .a13,
            parameterCount: "0.8B",
            quantization: "4-bit"
        ),
        AIModel(
            id: "qwen3_1_7B",
            configuration: ModelConfiguration(id: "mlx-community/Qwen3-1.7B-4bit"),
            category: .general,
            displayName: "Qwen3 1.7B",
            description: "Balanced multilingual model with advanced reasoning",
            estimatedRAMUsage: 1200,
            minimumChipRequired: .a13,
            parameterCount: "1.7B",
            quantization: "4-bit"
        ),
        AIModel(
            id: "qwen3_5_2B",
            configuration: ModelConfiguration(id: "mlx-community/Qwen3.5-2B-4bit"),
            category: .general,
            displayName: "Qwen3.5 2B",
            description: "Compact Qwen3.5 with strong multilingual reasoning",
            estimatedRAMUsage: 2000,
            minimumChipRequired: .a15,
            parameterCount: "2B",
            quantization: "4-bit"
        ),
        AIModel(
            id: "qwen3_4B_2507",
            configuration: ModelConfiguration(id: "mlx-community/Qwen3-4B-Instruct-2507-4bit"),
            category: .general,
            displayName: "Qwen3 4B (2507)",
            description: "Alibaba's updated flagship small model with strong reasoning",
            estimatedRAMUsage: 2600,
            minimumChipRequired: .a15,
            parameterCount: "4B",
            quantization: "4-bit"
        ),
        AIModel(
            id: "qwen3_5_4B",
            configuration: ModelConfiguration(id: "mlx-community/Qwen3.5-4B-MLX-4bit"),
            category: .general,
            displayName: "Qwen3.5 4B",
            description: "Capable Qwen3.5, excellent quality for its size",
            estimatedRAMUsage: 3400,
            minimumChipRequired: .a16,
            parameterCount: "4B",
            quantization: "4-bit"
        ),
        AIModel(
            id: "qwen3_8B",
            configuration: ModelConfiguration(id: "mlx-community/Qwen3-8B-4bit"),
            category: .general,
            displayName: "Qwen3 8B",
            description: "Large Qwen3 with top quality, best on iPad/Mac",
            estimatedRAMUsage: 5200,
            minimumChipRequired: .a17Pro,
            parameterCount: "8B",
            quantization: "4-bit"
        ),
        AIModel(
            id: "qwen3_5_9B",
            configuration: ModelConfiguration(id: "mlx-community/Qwen3.5-9B-4bit"),
            category: .general,
            displayName: "Qwen3.5 9B",
            description: "Largest Qwen3.5, flagship quality for ample-RAM devices",
            estimatedRAMUsage: 6600,
            minimumChipRequired: .a17Pro,
            parameterCount: "9B",
            quantization: "4-bit"
        ),

        // --- Gemma Series (NEW - Replaces Gemma 2) ---
        AIModel(
            id: "gemma3_1B",
            configuration: ModelConfiguration(id: "mlx-community/gemma-3-1b-it-qat-4bit"),
            category: .general,
            displayName: "Gemma 3 1B",
            description: "Google's compact model, QAT 4-bit for better quality",
            estimatedRAMUsage: 900,
            minimumChipRequired: .a13,
            parameterCount: "1B",
            quantization: "4-bit"
        ),
        AIModel(
            id: "gemma3_4B",
            configuration: ModelConfiguration(id: "mlx-community/gemma-3-text-4b-it-4bit"),
            category: .general,
            displayName: "Gemma 3 4B",
            description: "Google's capable 4B model with strong reasoning (text-only build)",
            estimatedRAMUsage: 3000,
            minimumChipRequired: .a15,
            parameterCount: "4B",
            quantization: "4-bit"
        ),
        AIModel(
            id: "gemma3n_E2B",
            configuration: ModelConfiguration(id: "mlx-community/gemma-3n-E2B-it-lm-4bit"),
            category: .general,
            displayName: "Gemma 3n E2B",
            description: "Google's efficient MatFormer model (text build)",
            estimatedRAMUsage: 2900,
            minimumChipRequired: .a15,
            parameterCount: "E2B",
            quantization: "4-bit"
        ),
        AIModel(
            id: "gemma4_e2b",
            configuration: ModelConfiguration(id: "mlx-community/gemma-4-e2b-it-4bit"),
            category: .general,
            displayName: "Gemma 4 E2B",
            description: "Google's newest small model, strong general performance",
            estimatedRAMUsage: 4000,
            minimumChipRequired: .a16,
            parameterCount: "E2B",
            quantization: "4-bit"
        ),
        AIModel(
            id: "gemma4_e4b",
            configuration: ModelConfiguration(id: "mlx-community/gemma-4-e4b-it-4bit"),
            category: .general,
            displayName: "Gemma 4 E4B",
            description: "Google's larger Gemma 4, high quality, best on iPad/Mac",
            estimatedRAMUsage: 5800,
            minimumChipRequired: .a17Pro,
            parameterCount: "E4B",
            quantization: "4-bit"
        ),

        // --- Compact multilingual (≤1.5B) ---
        AIModel(
            id: "ernie4_5_0_3B",
            configuration: ModelConfiguration(id: "mlx-community/ERNIE-4.5-0.3B-PT-4bit"),
            category: .general,
            displayName: "ERNIE 4.5 0.3B",
            description: "Baidu's tiny multilingual model, extremely light",
            estimatedRAMUsage: 300,
            minimumChipRequired: .a13,
            parameterCount: "0.3B",
            quantization: "4-bit"
        ),
        AIModel(
            id: "lfm2_5_1_2B",
            configuration: ModelConfiguration(id: "mlx-community/LFM2.5-1.2B-Instruct-4bit"),
            category: .general,
            displayName: "LFM2.5 1.2B",
            description: "Liquid AI's fast hybrid model, efficient on-device",
            estimatedRAMUsage: 800,
            minimumChipRequired: .a13,
            parameterCount: "1.2B",
            quantization: "4-bit"
        ),
        AIModel(
            id: "exaone4_1_2B",
            configuration: ModelConfiguration(id: "mlx-community/exaone-4.0-1.2b-4bit"),
            category: .general,
            displayName: "EXAONE 4.0 1.2B",
            description: "LG's compact bilingual model with solid reasoning",
            estimatedRAMUsage: 850,
            minimumChipRequired: .a13,
            parameterCount: "1.2B",
            quantization: "4-bit"
        ),
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
            id: "granite4_1B",
            configuration: ModelConfiguration(id: "mlx-community/granite-4.0-h-1b-4bit"),
            category: .general,
            displayName: "Granite 4.0 1B",
            description: "IBM's efficient hybrid model for everyday tasks",
            estimatedRAMUsage: 1000,
            minimumChipRequired: .a14,
            parameterCount: "1B",
            quantization: "4-bit"
        ),
        AIModel(
            id: "falconH1_1_5B",
            configuration: ModelConfiguration(id: "mlx-community/Falcon-H1-1.5B-Instruct-4bit"),
            category: .general,
            displayName: "Falcon-H1 1.5B",
            description: "TII's hybrid attention/Mamba model, compact and fast",
            estimatedRAMUsage: 1050,
            minimumChipRequired: .a14,
            parameterCount: "1.5B",
            quantization: "4-bit"
        ),

        // --- Mid-size (3-4B) ---
        AIModel(
            id: "smollm3_3B",
            configuration: ModelConfiguration(id: "mlx-community/SmolLM3-3B-4bit"),
            category: .general,
            displayName: "SmolLM3 3B",
            description: "HuggingFace's multilingual model with reasoning and long context",
            estimatedRAMUsage: 2000,
            minimumChipRequired: .a15,
            parameterCount: "3B",
            quantization: "4-bit"
        ),
        AIModel(
            id: "phi4_mini",
            configuration: ModelConfiguration(id: "mlx-community/Phi-4-mini-instruct-4bit"),
            category: .general,
            displayName: "Phi-4 Mini",
            description: "Microsoft's powerful compact model, GPT-4 class performance",
            estimatedRAMUsage: 2200,
            minimumChipRequired: .a15,
            parameterCount: "3.8B",
            quantization: "4-bit"
        ),
        AIModel(
            id: "nemotron3_nano_4B",
            configuration: ModelConfiguration(id: "mlx-community/NVIDIA-Nemotron-3-Nano-4B-4bit"),
            category: .general,
            displayName: "Nemotron 3 Nano 4B",
            description: "NVIDIA's efficient hybrid model with strong reasoning",
            estimatedRAMUsage: 2600,
            minimumChipRequired: .a15,
            parameterCount: "4B",
            quantization: "4-bit"
        ),
        AIModel(
            id: "ministral3_3B",
            configuration: ModelConfiguration(id: "mlx-community/Ministral-3-3B-Instruct-2512-4bit"),
            category: .general,
            displayName: "Ministral 3 3B",
            description: "Mistral's compact 2025 model with strong quality",
            estimatedRAMUsage: 3100,
            minimumChipRequired: .a15,
            parameterCount: "3B",
            quantization: "4-bit"
        ),

        // --- Large general (best on iPad / Mac · M-class) ---
        AIModel(
            id: "olmo3_7B",
            configuration: ModelConfiguration(id: "mlx-community/Olmo-3-7B-Instruct-4bit"),
            category: .general,
            displayName: "OLMo 3 7B",
            description: "AllenAI's fully open 7B model, best on iPad/Mac",
            estimatedRAMUsage: 4600,
            minimumChipRequired: .a17Pro,
            parameterCount: "7B",
            quantization: "4-bit"
        ),
        AIModel(
            id: "apertus_8B",
            configuration: ModelConfiguration(id: "mlx-community/Apertus-8B-Instruct-2509-4bit"),
            category: .general,
            displayName: "Apertus 8B",
            description: "Swiss fully open multilingual 8B, best on iPad/Mac",
            estimatedRAMUsage: 5100,
            minimumChipRequired: .a17Pro,
            parameterCount: "8B",
            quantization: "4-bit"
        ),

        // --- Legacy Models (Lower Priority) ---
        AIModel(
            id: "qwen2_5_0_5B",
            configuration: ModelConfiguration(id: "mlx-community/Qwen2.5-0.5B-Instruct-4bit"),
            category: .general,
            displayName: "Qwen 2.5 0.5B",
            description: "Ultra-lightweight multilingual model (Legacy)",
            estimatedRAMUsage: 400,
            minimumChipRequired: .a13,
            parameterCount: "0.5B",
            quantization: "4-bit",
            isLegacy: true
        ),
        AIModel(
            id: "qwen2_5_1_5B",
            configuration: ModelConfiguration(id: "mlx-community/Qwen2.5-1.5B-Instruct-4bit"),
            category: .general,
            displayName: "Qwen 2.5 1.5B",
            description: "Balanced multilingual model from Alibaba (Legacy)",
            estimatedRAMUsage: 1200,
            minimumChipRequired: .a13,
            parameterCount: "1.5B",
            quantization: "4-bit",
            isLegacy: true
        ),
        AIModel(
            id: "gemma2_2B",
            configuration: ModelConfiguration(id: "mlx-community/gemma-2-2b-it-4bit"),
            category: .general,
            displayName: "Gemma 2 2B",
            description: "Google's lightweight model (Legacy)",
            estimatedRAMUsage: 1600,
            minimumChipRequired: .a14,
            parameterCount: "2B",
            quantization: "4-bit",
            isLegacy: true
        ),

        // ============================================
        // CODE MODELS
        // ============================================
        AIModel(
            id: "qwen2_5_coder_0_5B",
            configuration: ModelConfiguration(id: "mlx-community/Qwen2.5-Coder-0.5B-Instruct-4bit"),
            category: .code,
            displayName: "Qwen Coder 0.5B",
            description: "Ultra-lightweight code assistant",
            estimatedRAMUsage: 400,
            minimumChipRequired: .a13,
            parameterCount: "0.5B",
            quantization: "4-bit"
        ),
        AIModel(
            id: "qwen2_5_coder_1_5B",
            configuration: ModelConfiguration(id: "mlx-community/Qwen2.5-Coder-1.5B-Instruct-4bit"),
            category: .code,
            displayName: "Qwen Coder 1.5B",
            description: "Balanced code assistant for most programming tasks",
            estimatedRAMUsage: 1000,
            minimumChipRequired: .a13,
            parameterCount: "1.5B",
            quantization: "4-bit"
        ),
        AIModel(
            id: "qwen2_5_coder_3B",
            configuration: ModelConfiguration(id: "mlx-community/Qwen2.5-Coder-3B-Instruct-4bit"),
            category: .code,
            displayName: "Qwen Coder 3B",
            description: "Advanced code assistant with strong capabilities",
            estimatedRAMUsage: 2000,
            minimumChipRequired: .a15,
            parameterCount: "3B",
            quantization: "4-bit"
        ),

        // ============================================
        // REASONING MODELS
        // ============================================
        AIModel(
            id: "lfm2_5_thinking_1_2B",
            configuration: ModelConfiguration(id: "mlx-community/LFM2.5-1.2B-Thinking-4bit"),
            category: .reasoning,
            displayName: "LFM2.5 Thinking 1.2B",
            description: "Liquid AI's lightweight thinking model, fast on-device",
            estimatedRAMUsage: 800,
            minimumChipRequired: .a13,
            parameterCount: "1.2B",
            quantization: "4-bit"
        ),
        AIModel(
            id: "deepseekR1_1_5B_4bit",
            configuration: ModelConfiguration(id: "mlx-community/DeepSeek-R1-Distill-Qwen-1.5B-4bit"),
            category: .reasoning,
            displayName: "DeepSeek R1 1.5B",
            description: "Advanced reasoning with chain-of-thought capabilities",
            estimatedRAMUsage: 1200,
            minimumChipRequired: .a14,
            parameterCount: "1.5B",
            quantization: "4-bit"
        ),
        AIModel(
            id: "openmath_nemotron_1_5B",
            configuration: ModelConfiguration(id: "mlx-community/OpenMath-Nemotron-1.5B-4bit"),
            category: .reasoning,
            displayName: "OpenMath Nemotron 1.5B",
            description: "Compact math-focused reasoning model",
            estimatedRAMUsage: 1050,
            minimumChipRequired: .a14,
            parameterCount: "1.5B",
            quantization: "4-bit"
        ),
        AIModel(
            id: "cogito_v1_3B",
            configuration: ModelConfiguration(id: "mlx-community/deepcogito-cogito-v1-preview-llama-3B-4bit"),
            category: .reasoning,
            displayName: "Cogito v1 3B",
            description: "Hybrid reasoning model with deliberate thinking",
            estimatedRAMUsage: 2100,
            minimumChipRequired: .a15,
            parameterCount: "3B",
            quantization: "4-bit"
        ),
        AIModel(
            id: "ministral3_reasoning_3B",
            configuration: ModelConfiguration(id: "mlx-community/Ministral-3-3B-Reasoning-2512-4bit"),
            category: .reasoning,
            displayName: "Ministral 3 Reasoning 3B",
            description: "Mistral's compact reasoning model",
            estimatedRAMUsage: 3100,
            minimumChipRequired: .a15,
            parameterCount: "3B",
            quantization: "4-bit"
        ),
        AIModel(
            id: "olmo3_think_7B",
            configuration: ModelConfiguration(id: "mlx-community/Olmo-3-7B-Think-4bit"),
            category: .reasoning,
            displayName: "OLMo 3 Think 7B",
            description: "AllenAI's open reasoning model, best on iPad/Mac",
            estimatedRAMUsage: 4600,
            minimumChipRequired: .a17Pro,
            parameterCount: "7B",
            quantization: "4-bit"
        )
    ]

    // MARK: - System Models (DEV-598)

    /// The Apple Foundation Models entry. Defined as a value always; its
    /// visibility is gated on runtime availability via `systemModels`.
    static let appleFoundationModel = AIModel(
        id: "apple_foundation",
        source: .appleFoundation,
        category: .general,
        displayName: "Apple Intelligence",
        description: "Apple's built-in on-device model. No download required.",
        estimatedRAMUsage: 0,
        minimumChipRequired: .a17Pro,
        parameterCount: "Built-in",
        quantization: "System"
    )

    /// System-managed models that are currently available on this device.
    private var systemModels: [AIModel] {
        AppleIntelligenceAvailability.current.isUsable ? [Self.appleFoundationModel] : []
    }

    // MARK: - Public API

    /// All models offered on this device: the bundled MLX catalog plus any
    /// currently available system-managed models (e.g. Apple Intelligence).
    var allModels: [AIModel] {
        systemModels + models
    }

    /// Returns models sorted by priority (non-legacy first, then by RAM usage)
    var sortedModels: [AIModel] {
        allModels.sorted { m1, m2 in
            if m1.isLegacy != m2.isLegacy {
                return !m1.isLegacy // Non-legacy first
            }
            return m1.estimatedRAMUsage < m2.estimatedRAMUsage
        }
    }

    var categorizedModels: [ModelCategory: [AIModel]] {
        let grouped = Dictionary(grouping: allModels, by: { $0.category })
        return grouped.mapValues { models in
            models.sorted { m1, m2 in
                if m1.isLegacy != m2.isLegacy {
                    return !m1.isLegacy
                }
                return m1.estimatedRAMUsage < m2.estimatedRAMUsage
            }
        }
    }

    var defaultModel: AIModel {
        // Default to Qwen3 0.6B as it's small and capable
        models.first { $0.id == "qwen3_0_6B" } ?? models[0]
    }

    func modelByConfiguration(_ configuration: ModelConfiguration) -> AIModel? {
        models.first { $0.mlxConfiguration?.name == configuration.name }
    }

    func modelByName(_ name: String) -> AIModel? {
        models.first { $0.mlxConfiguration?.name == name }
    }

    func modelById(_ id: String) -> AIModel? {
        allModels.first { $0.id == id }
    }

    // MARK: - Compatibility
    func compatibilityForModel(_ model: AIModel) -> ModelCompatibility {
        // System-managed models (Apple Intelligence) only appear when the OS
        // reports them available, so they are always a good fit by definition.
        if model.isSystemManaged {
            return .recommended
        }

        let chipFamily = DeviceUtils.chipFamily
        let deviceRAM = DeviceUtils.estimatedRAM

        // Safety net: hardware newer than our chip table resolves to .unknown.
        // If the device supports Metal 3 it can run MLX, so don't blanket-block it —
        // otherwise a brand-new top-tier device (e.g. a future iPhone) would show
        // every model as "Not recommended - High crash risk".
        if chipFamily == .unknown && DeviceUtils.canRunMLX {
            return .compatible
        }

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
        allModels.filter { model in
            let compatibility = compatibilityForModel(model)
            return compatibility == .recommended || compatibility == .compatible
        }.sorted { model1, model2 in
            // Sort by: non-legacy first, then compatibility, then RAM usage
            if model1.isLegacy != model2.isLegacy {
                return !model1.isLegacy
            }

            let comp1 = compatibilityForModel(model1)
            let comp2 = compatibilityForModel(model2)

            if comp1 == comp2 {
                return model1.estimatedRAMUsage < model2.estimatedRAMUsage
            }

            return comp1 == .recommended && comp2 != .recommended
        }
    }

    func modelsForCategory(_ category: ModelCategory) -> [AIModel] {
        allModels.filter { $0.category == category }.sorted { m1, m2 in
            if m1.isLegacy != m2.isLegacy {
                return !m1.isLegacy
            }
            return m1.estimatedRAMUsage < m2.estimatedRAMUsage
        }
    }

    /// Returns only non-legacy models
    var currentModels: [AIModel] {
        allModels.filter { !$0.isLegacy }
    }

    /// Returns only legacy models
    var legacyModels: [AIModel] {
        allModels.filter { $0.isLegacy }
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
        case .a19:
            return 8192  // 8GB (iPhone 17)
        case .a19Pro:
            return 12288 // 12GB (iPhone 17 Pro/Pro Max, iPhone Air)
        case .m1, .m2:
            return 8192  // 8GB minimum
        case .m3, .m4, .m5:
            return 16384 // 16GB minimum
        default:
            return 4096  // Conservative estimate
        }
    }
}
