//
//  ChatEngine.swift
//  Eris.
//
//  Inference-provider abstraction introduced in DEV-597.
//

import Foundation

/// Receives incremental generation updates from a `ChatEngine` so a UI-facing
/// observable (e.g. `ChatEngineRunner`) can republish them as `@Published` state.
@MainActor
protocol ChatEngineDelegate: AnyObject {
    /// The engine started or finished the (possibly slow) model loading phase.
    func chatEngine(_ engine: ChatEngine, didChangeLoadingState isLoading: Bool)

    /// Download/preparation progress in the `0...1` range (MLX only).
    func chatEngine(_ engine: ChatEngine, didUpdateDownloadProgress fraction: Double)

    /// New cumulative output text together with the running token count.
    func chatEngine(_ engine: ChatEngine, didProduceOutput cumulativeText: String, tokenCount: Int)
}

/// A backend capable of producing a chat completion for a conversation.
///
/// Concrete engines:
/// - `MLXEngine` — on-device MLX model downloaded from Hugging Face.
/// - `FoundationModelsEngine` — Apple's system model (added in DEV-598).
///
/// Engines report streaming progress through `delegate` and return the final
/// text. They never touch UI state directly, which keeps them reusable from
/// both `ChatView` and App Intents.
@MainActor
protocol ChatEngine: AnyObject {
    /// Generates a response for `thread` using `systemPrompt`, streaming partial
    /// output through `delegate`. Returns the final, complete text (or a
    /// user-facing error string on failure).
    func generate(thread: Thread, systemPrompt: String, delegate: ChatEngineDelegate) async -> String

    /// Requests cancellation of the in-flight generation, if any.
    func cancel()
}
