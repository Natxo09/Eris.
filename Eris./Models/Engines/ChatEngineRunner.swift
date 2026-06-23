//
//  ChatEngineRunner.swift
//  Eris.
//
//  UI-facing coordinator that drives a `ChatEngine` and republishes its
//  streaming state. Replaces the role `LLMEvaluator` used to play for the two
//  generation call-sites (ChatView and App Intents). Introduced in DEV-597.
//

import SwiftUI

@MainActor
final class ChatEngineRunner: ObservableObject, ChatEngineDelegate {
    @Published var running = false
    @Published var isLoadingModel = false
    @Published var output = ""
    @Published var progress = 0.0
    @Published var tokensGenerated = 0

    // Concrete engines are cached so each keeps its own load state across
    // messages (the MLX engine caches the loaded `ModelContainer`).
    private lazy var mlxEngine = MLXEngine()
    private var foundationEngine: ChatEngine?
    private var currentEngine: ChatEngine?

    /// Resolves the engine for a given source.
    private func engine(for source: ModelSource) -> ChatEngine {
        switch source {
        case .mlx:
            return mlxEngine
        case .appleFoundation:
            if #available(iOS 26.0, *) {
                if let foundationEngine { return foundationEngine }
                let engine = FoundationModelsEngine()
                foundationEngine = engine
                return engine
            }
            // Unreachable in practice: the Apple model is never offered below
            // iOS 26, but the switch must stay exhaustive.
            return mlxEngine
        }
    }

    func generate(thread: Thread, systemPrompt: String = "You are a helpful assistant.") async -> String {
        guard !running else { return "" }

        running = true
        output = ""
        tokensGenerated = 0
        progress = 0
        isLoadingModel = false

        guard let aiModel = ModelManager.shared.activeAIModel else {
            output = "Error: No model selected"
            running = false
            return output
        }

        let engine = engine(for: aiModel.source)
        currentEngine = engine

        let result = await engine.generate(thread: thread, systemPrompt: systemPrompt, delegate: self)

        output = result
        running = false
        currentEngine = nil
        return result
    }

    /// Requests cancellation of the in-flight generation.
    func stop() {
        (currentEngine ?? mlxEngine).cancel()
    }

    // MARK: - ChatEngineDelegate

    func chatEngine(_ engine: ChatEngine, didChangeLoadingState isLoading: Bool) {
        isLoadingModel = isLoading
    }

    func chatEngine(_ engine: ChatEngine, didUpdateDownloadProgress fraction: Double) {
        progress = fraction
    }

    func chatEngine(_ engine: ChatEngine, didProduceOutput cumulativeText: String, tokenCount: Int) {
        output = cumulativeText
        tokensGenerated = tokenCount
    }
}
