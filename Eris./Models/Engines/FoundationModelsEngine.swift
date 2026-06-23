//
//  FoundationModelsEngine.swift
//  Eris.
//
//  Apple Foundation Models backed `ChatEngine` (DEV-598). Uses the system
//  on-device model that powers Apple Intelligence — no download and no RAM
//  management. Available on iOS 26+ with Apple Intelligence enabled.
//

import Foundation
import FoundationModels

/// Apple Intelligence availability, queryable from code that is not itself
/// gated behind `@available(iOS 26, *)`. Wraps `SystemLanguageModel.availability`
/// and adds an explicit case for running on an OS older than iOS 26.
enum AppleIntelligenceAvailability: Equatable {
    case available
    case appleIntelligenceNotEnabled
    case deviceNotEligible
    case modelNotReady
    case unsupportedOS
    case unknown

    static var current: AppleIntelligenceAvailability {
        guard #available(iOS 26.0, *) else { return .unsupportedOS }
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(.appleIntelligenceNotEnabled):
            return .appleIntelligenceNotEnabled
        case .unavailable(.deviceNotEligible):
            return .deviceNotEligible
        case .unavailable(.modelNotReady):
            return .modelNotReady
        case .unavailable:
            return .unknown
        }
    }

    /// `true` only when the model is ready to serve requests.
    var isUsable: Bool { self == .available }
}

@available(iOS 26.0, *)
@MainActor
final class FoundationModelsEngine: ChatEngine {
    private var isCancelled = false

    func cancel() {
        isCancelled = true
    }

    func generate(thread: Thread, systemPrompt: String, delegate: ChatEngineDelegate) async -> String {
        isCancelled = false
        // The system model is always resident — there is no loading phase.
        delegate.chatEngine(self, didChangeLoadingState: false)

        guard SystemLanguageModel.default.isAvailable else {
            let message = Self.unavailableMessage(for: SystemLanguageModel.default.availability)
            delegate.chatEngine(self, didProduceOutput: message, tokenCount: 0)
            return message
        }

        // The latest message is the new user turn; everything before it is history.
        let messages = thread.sortedMessages
        let promptText = messages.last?.content ?? ""
        let history = Array(messages.dropLast())

        let session = LanguageModelSession(
            transcript: Self.buildTranscript(systemPrompt: systemPrompt, history: history)
        )

        var output = ""
        var tokens = 0
        do {
            let stream = session.streamResponse(to: promptText)
            for try await snapshot in stream {
                if isCancelled { break }
                output = snapshot.content
                tokens += 1
                delegate.chatEngine(self, didProduceOutput: output, tokenCount: tokens)
            }
        } catch {
            output = Self.friendlyError(error)
            delegate.chatEngine(self, didProduceOutput: output, tokenCount: tokens)
            print("❌ FoundationModels generation error: \(error)")
        }

        return output
    }

    // MARK: - Helpers

    /// Rebuilds the conversation as a `Transcript` so the system model has the
    /// full multi-turn context for each (stateless) generation call.
    private static func buildTranscript(systemPrompt: String, history: [Message]) -> Transcript {
        var entries: [Transcript.Entry] = [
            .instructions(
                Transcript.Instructions(
                    segments: [textSegment(systemPrompt)],
                    toolDefinitions: []
                )
            )
        ]

        for message in history {
            switch message.role {
            case .user, .system:
                entries.append(.prompt(Transcript.Prompt(segments: [textSegment(message.content)])))
            case .assistant:
                entries.append(.response(Transcript.Response(assetIDs: [], segments: [textSegment(message.content)])))
            }
        }

        return Transcript(entries: entries)
    }

    private static func textSegment(_ content: String) -> Transcript.Segment {
        .text(Transcript.TextSegment(id: UUID().uuidString, content: content))
    }

    private static func friendlyError(_ error: Error) -> String {
        if let generationError = error as? LanguageModelSession.GenerationError {
            switch generationError {
            case .exceededContextWindowSize:
                return "Error: This conversation is too long for Apple Intelligence. Start a new chat to continue."
            default:
                return "Error: \(error.localizedDescription)"
            }
        }
        return "Error: \(error.localizedDescription)"
    }

    private static func unavailableMessage(for availability: SystemLanguageModel.Availability) -> String {
        switch availability {
        case .available:
            return "Apple Intelligence is currently unavailable."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence is turned off. Enable it in Settings to use this model."
        case .unavailable(.deviceNotEligible):
            return "This device doesn't support Apple Intelligence."
        case .unavailable(.modelNotReady):
            return "Apple Intelligence is still preparing. Please try again in a moment."
        case .unavailable:
            return "Apple Intelligence is currently unavailable."
        }
    }
}
