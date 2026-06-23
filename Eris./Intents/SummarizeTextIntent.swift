//
//  SummarizeTextIntent.swift
//  Eris.
//
//  Created by Assistant on 28/6/25.
//

import AppIntents
import SwiftData
import SwiftUI

@available(iOS 16.0, *)
struct SummarizeTextIntent: AppIntent {
    static var title: LocalizedStringResource = "Summarize Text"
    static var description: LocalizedStringResource = "Get a summary of any text using Eris"
    
    @Parameter(title: "Text to Summarize", description: "The text you want to summarize")
    var text: String
    
    @Parameter(title: "Summary Length", description: "How long should the summary be", default: .medium)
    var summaryLength: SummaryLength
    
    @Parameter(title: "Save Chat", description: "Save this task in the app", default: false)
    var saveChat: Bool
    
    @Parameter(title: "Model Name", description: "Type the model name (e.g., 'Llama', 'Qwen', 'Gemma') or leave empty for default")
    var modelName: String?
    
    static var parameterSummary: some ParameterSummary {
        Summary("Summarize this text: \(\.$text)") {
            \.$summaryLength
            \.$saveChat
            \.$modelName
        }
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        // Select the model to use
        let modelResult = IntentUtils.selectModel(requestedName: modelName)
        guard case .success(let selectedModel) = modelResult else {
            if case .failure(let error) = modelResult {
                let errorMessage = error.localizedDescription
                return .result(value: errorMessage, dialog: IntentDialog(stringLiteral: errorMessage))
            }
            return .result(value: "Unknown error", dialog: IntentDialog(stringLiteral: "Unknown error"))
        }
        
        // Create prompt for summarization
        let prompt = """
        Please summarize the following text in a \(summaryLength.rawValue) format:
        
        \(text)
        """
        
        // Create a thread for this task
        let thread = Thread(title: "Summary: \(text.prefix(30))...")
        let userMessage = Message(content: prompt, role: .user)
        thread.addMessage(userMessage)
        
        // Generate summary
        let systemPrompt = "You are an expert at creating clear, concise summaries. Focus on the key points and main ideas."
        let summary = await IntentUtils.generateResponse(
            thread: thread,
            model: selectedModel,
            systemPrompt: systemPrompt
        )
        
        // Add assistant response
        let assistantMessage = Message(content: summary, role: .assistant)
        thread.addMessage(assistantMessage)
        
        // Save the chat if requested
        IntentUtils.saveThreadIfNeeded(thread, saveChat: saveChat)
        
        return .result(value: summary, dialog: IntentDialog(stringLiteral: summary))
    }
    
    static var openAppWhenRun: Bool = false
}

// Summary length options
enum SummaryLength: String, AppEnum {
    case brief = "brief"
    case medium = "medium"
    case detailed = "detailed"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Summary Length"
    
    static var caseDisplayRepresentations: [SummaryLength: DisplayRepresentation] = [
        .brief: "Brief - 1-2 sentences",
        .medium: "Medium - 1 paragraph",
        .detailed: "Detailed - Multiple paragraphs"
    ]
}