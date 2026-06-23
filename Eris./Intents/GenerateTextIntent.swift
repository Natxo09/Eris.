//
//  GenerateTextIntent.swift
//  Eris.
//
//  Created by Assistant on 28/6/25.
//

import AppIntents
import SwiftData
import SwiftUI

@available(iOS 16.0, *)
struct GenerateTextIntent: AppIntent {
    static var title: LocalizedStringResource = "Generate Text"
    static var description: LocalizedStringResource = "Generate creative text with Eris"
    
    @Parameter(title: "Type of Text", description: "What kind of text to generate", default: .paragraph)
    var textType: TextType
    
    @Parameter(title: "Topic or Context", description: "What the text should be about")
    var topic: String
    
    @Parameter(title: "Tone", description: "The tone of the text", default: .neutral)
    var tone: WritingTone
    
    @Parameter(title: "Save Chat", description: "Save this generation in the app", default: false)
    var saveChat: Bool
    
    @Parameter(title: "Model Name", description: "Type the model name (e.g., 'Llama', 'Qwen', 'Gemma') or leave empty for default")
    var modelName: String?
    
    static var parameterSummary: some ParameterSummary {
        Summary("Generate \(\.$textType) about \(\.$topic)") {
            \.$tone
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
        
        // Build generation prompt
        let prompt = buildPrompt(for: textType, topic: topic, tone: tone)
        
        // Create a thread
        let thread = Thread(title: "Generate: \(textType.rawValue)")
        let userMessage = Message(content: prompt, role: .user)
        thread.addMessage(userMessage)
        
        // Generate text
        let systemPrompt = "You are a creative writing assistant. Generate high-quality content that matches the requested style and tone."
        let generatedText = await IntentUtils.generateResponse(
            thread: thread,
            model: selectedModel,
            systemPrompt: systemPrompt
        )
        
        // Add assistant response
        let assistantMessage = Message(content: generatedText, role: .assistant)
        thread.addMessage(assistantMessage)
        
        // Save the chat if requested
        IntentUtils.saveThreadIfNeeded(thread, saveChat: saveChat)
        
        return .result(value: generatedText, dialog: IntentDialog(stringLiteral: generatedText))
    }
    
    private func buildPrompt(for type: TextType, topic: String, tone: WritingTone) -> String {
        let toneDescription = tone.description
        
        switch type {
        case .email:
            return "Write a \(toneDescription) email about: \(topic)"
        case .message:
            return "Write a \(toneDescription) message about: \(topic)"
        case .socialPost:
            return "Write a \(toneDescription) social media post about: \(topic)"
        case .paragraph:
            return "Write a \(toneDescription) paragraph about: \(topic)"
        case .list:
            return "Create a \(toneDescription) list about: \(topic)"
        case .idea:
            return "Generate creative ideas about: \(topic). Use a \(toneDescription) approach."
        }
    }
    
    static var openAppWhenRun: Bool = false
}

// Text type options
enum TextType: String, AppEnum {
    case email = "Email"
    case message = "Message"
    case socialPost = "Social Post"
    case paragraph = "Paragraph"
    case list = "List"
    case idea = "Ideas"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Text Type"
    
    static var caseDisplayRepresentations: [TextType: DisplayRepresentation] = [
        .email: "Email",
        .message: "Message",
        .socialPost: "Social Media Post",
        .paragraph: "Paragraph",
        .list: "List",
        .idea: "Creative Ideas"
    ]
}

// Writing tone options
enum WritingTone: String, AppEnum {
    case professional = "professional"
    case casual = "casual"
    case friendly = "friendly"
    case formal = "formal"
    case humorous = "humorous"
    case neutral = "neutral"
    
    var description: String {
        switch self {
        case .professional: return "professional"
        case .casual: return "casual"
        case .friendly: return "friendly"
        case .formal: return "formal"
        case .humorous: return "humorous"
        case .neutral: return "neutral"
        }
    }
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Writing Tone"
    
    static var caseDisplayRepresentations: [WritingTone: DisplayRepresentation] = [
        .professional: "Professional",
        .casual: "Casual",
        .friendly: "Friendly",
        .formal: "Formal",
        .humorous: "Humorous",
        .neutral: "Neutral"
    ]
}