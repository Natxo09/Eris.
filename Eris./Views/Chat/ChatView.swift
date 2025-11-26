//
//  ChatView.swift
//  Eris.
//
//  Created by Ignacio Palacio on 19/6/25.
//

import SwiftUI
import SwiftData
import MLXLMCommon


struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var llmEvaluator = LLMEvaluator()
    @StateObject private var modelManager = ModelManager.shared
    @StateObject private var scrollManager = ChatScrollManager()
    @FocusState private var isInputFocused: Bool
    
    let thread: Thread
    
    @State private var inputText = ""
    @State private var isGenerating = false
    @State private var showNoModelAlert = false
    @State private var showModelPicker = false
    @State private var lastHapticTokenCount = 0
    @State private var isScrolledToBottom = true
    @State private var showDeviceWarning = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ZStack(alignment: .bottom) {
                ScrollViewReader { proxy in
                ScrollView {
                        VStack(spacing: 16) {
                        // Empty state
                        if thread.sortedMessages.isEmpty && !llmEvaluator.running {
                            EmptyChatView()
                                .padding(.top, 100)
                        }
                        
                        // Messages - LazyVStack only renders visible messages
                        ForEach(thread.sortedMessages, id: \.id) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                        
                        // Typing indicator
                        if llmEvaluator.running {
                            TypingIndicator(text: llmEvaluator.output)
                                .transition(.scale.combined(with: .opacity))
                        }
                        
                        // Bottom anchor for scrolling
                        GeometryReader { geometry in
                            Color.clear
                                .id("bottom")
                                .onChange(of: geometry.frame(in: .global).minY) { _, minY in
                                    // Check if bottom is visible
                                    let screenHeight = UIScreen.main.bounds.height
                                    let isBottomVisible = minY < screenHeight && minY > 0
                                    
                                    scrollManager.showScrollToBottomButton = !isBottomVisible
                                    scrollManager.isAtBottom = isBottomVisible
                                }
                                .onAppear {
                                    let minY = geometry.frame(in: .global).minY
                                    let screenHeight = UIScreen.main.bounds.height
                                    let isBottomVisible = minY < screenHeight && minY > 0
                                    
                                    scrollManager.showScrollToBottomButton = !isBottomVisible
                                    scrollManager.isAtBottom = isBottomVisible
                                }
                        }
                        .frame(height: 20)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                }
                .scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom) {
                    // This creates space for the keyboard
                    Color.clear.frame(height: 0)
                }
                .onAppear {
                    scrollManager.setProxy(proxy)
                    scrollManager.scrollToBottomSmooth()
                }
                .onChange(of: thread.messages.count) { oldCount, newCount in
                    if newCount > oldCount {
                        scrollManager.handleNewMessage()
                    }
                }
                .onChange(of: llmEvaluator.running) { _, newValue in
                    if newValue {
                        scrollManager.handleTypingStarted()
                    }
                }
                .onChange(of: llmEvaluator.output) { _, _ in
                    scrollManager.handleContentUpdate()
                }
                .onChange(of: llmEvaluator.tokensGenerated) { _, newTokenCount in
                    // Check if we're generating a code block
                    let codeBlockStarts = llmEvaluator.output.components(separatedBy: "```").count - 1
                    let isGeneratingCode = codeBlockStarts % 2 == 1
                    
                    // Haptic feedback only if we're scrolled to bottom and NOT generating code
                    if isScrolledToBottom && !isGeneratingCode && newTokenCount > lastHapticTokenCount + 12 {
                        // Alternate between different haptic patterns
                        let hapticCount = newTokenCount / 12
                        switch hapticCount % 3 {
                        case 0:
                            HapticManager.shared.impact(.soft)
                        case 1:
                            HapticManager.shared.impact(.light)
                        default:
                            HapticManager.shared.selection()
                        }
                        lastHapticTokenCount = newTokenCount
                    }
                }
                }
                
                // Scroll to bottom button with slide animation
                Button(action: {
                    HapticManager.shared.selection()
                    withAnimation(.easeOut(duration: 0.3)) {
                        scrollManager.scrollToBottom()
                    }
                }) {
                    if #available(iOS 26.0, *) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color(UIColor.label))
                            .frame(width: 44, height: 44)
                            .glassEffect(.regular.interactive(), in: .circle)
                    } else {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.gray.opacity(0.9)))
                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.bottom, 16)
                .opacity(scrollManager.showScrollToBottomButton ? 1 : 0)
                .offset(y: scrollManager.showScrollToBottomButton ? 0 : 50)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: scrollManager.showScrollToBottomButton)
                .allowsHitTesting(scrollManager.showScrollToBottomButton)
            }
            
            // Input area with model selector
            VStack(spacing: 0) {
                ChatInputView(
                    text: $inputText,
                    isGenerating: llmEvaluator.running,
                    isLoadingModel: llmEvaluator.isLoadingModel,
                    onSend: {
                        HapticManager.shared.messageSent()
                        sendMessage()
                    },
                    onStop: {
                        llmEvaluator.stopGeneration()
                    }
                )
                .focused($isInputFocused)
            }
            .background {
                if #available(iOS 26.0, *) {
                    UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20)
                        .fill(.clear)
                        .glassEffect(.regular, in: UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    Color(UIColor.secondarySystemBackground)
                        .clipShape(
                            .rect(
                                topLeadingRadius: 20,
                                topTrailingRadius: 20
                            )
                        )
                        .ignoresSafeArea(edges: .bottom)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, y: -2)
                }
            }
        }
        .navigationTitle(thread.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if let activeModel = modelManager.activeModel {
                    Button(action: {
                        HapticManager.shared.selection()
                        showModelPicker.toggle()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "cpu")
                                .font(.system(size: 14, weight: .medium))
                            Text(formatModelName(activeModel))
                                .font(.system(size: 14, weight: .medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(Color(UIColor.label))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(UIColor.tertiarySystemFill))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(UIColor.separator).opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .alert("No Model Selected", isPresented: $showNoModelAlert) {
            Button("Go to Settings") {
                // User needs to navigate to model management
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please download and select a model before chatting.")
        }
        .alert("Device Limitations", isPresented: $showDeviceWarning) {
            Button("Try Anyway") {
                actualSendMessage()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This model may have issues on your \(DeviceUtils.deviceDescription). For best results:\n\n• Close all other apps\n• Restart your device if needed\n• Consider using a smaller model\n\nThe app may crash if memory is insufficient.")
        }
        .onAppear {
            updateTitle()
        }
        .sheet(isPresented: $showModelPicker) {
            NavigationStack {
                ModelPickerView(selectedModel: modelManager.activeModel) { model in
                    modelManager.setActiveModel(model)
                    showModelPicker = false
                }
                .navigationTitle("Select Model")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showModelPicker = false
                        }
                    }
                }
            }
            .presentationDetents([.fraction(0.4)])
            .presentationDragIndicator(.visible)
        }
    }
    
    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        
        // Check if model is selected
        guard modelManager.activeModel != nil else {
            showNoModelAlert = true
            return
        }
        
        // Check if selected model is risky or not recommended for this device
        if let activeAIModel = modelManager.activeAIModel {
            let compatibility = AIModelsRegistry.shared.compatibilityForModel(activeAIModel)
            if compatibility == .risky || compatibility == .notRecommended {
                showDeviceWarning = true
                return
            }
        }
        
        actualSendMessage()
    }
    
    private func actualSendMessage() {
        // Check if thread is persisted, if not, insert it now
        if thread.modelContext == nil {
            modelContext.insert(thread)
        }
        
        // Add user message
        let userMessage = Message(content: inputText, role: .user)
        thread.addMessage(userMessage)
        
        // Update title after first message
        updateTitle()
        
        let prompt = inputText
        inputText = ""
        
        // Dismiss keyboard
        isInputFocused = false
        
        // Generate response
        Task {
            // Haptic when AI starts generating
            HapticManager.shared.processingStart()
            
            let systemPrompt = """
            You are Eris, a helpful AI assistant integrated into the Eris app - a privacy-focused iOS application that runs language models entirely on-device. 
            
            Key facts about yourself and the app:
            - You run locally on the user's iPhone/iPad without any cloud connectivity
            - All conversations are stored privately on the device
            - You are powered by various open-source models (Llama, Qwen, Mistral, etc.)
            - The app prioritizes user privacy and data security
            - You support markdown formatting and code syntax highlighting
            
            Be helpful, concise, and privacy-conscious in your responses.
            """
            
            let response = await llmEvaluator.generate(thread: thread, systemPrompt: systemPrompt)
            
            // Add assistant message
            let assistantMessage = Message(content: response, role: .assistant)
            thread.addMessage(assistantMessage)
            
            // Haptic feedback for received message
            HapticManager.shared.messageReceived()
            
            // Save context
            try? modelContext.save()
        }
    }
    
    private func updateTitle() {
        // Auto-generate title from first message if needed
        if thread.title == "New Chat", 
           let firstUserMessage = thread.sortedMessages.first(where: { $0.role == .user }) {
            let words = firstUserMessage.content.split(separator: " ").prefix(5)
            thread.title = words.joined(separator: " ")
            if firstUserMessage.content.count > thread.title.count {
                thread.title += "..."
            }
        }
    }
    
    private func formatModelName(_ model: MLXLMCommon.ModelConfiguration) -> String {
        model.name
            .replacingOccurrences(of: "mlx-community/", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "Instruct", with: "")
            .replacingOccurrences(of: "4bit", with: "")
            .replacingOccurrences(of: "8bit", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Chat Components

struct MessageBubble: View {
    let message: Message
    @State private var showTimestamp = false
    
    var body: some View {
        if message.role == .user {
            // User message with bubble on the right
            HStack(alignment: .bottom, spacing: 8) {
                Spacer(minLength: 60)
                
                VStack(alignment: .trailing, spacing: 4) {
                    MessageView(content: message.content, isUser: true)
                        .contextMenu {
                            Button(action: {
                                UIPasteboard.general.string = message.content
                                HapticManager.shared.notification(.success)
                            }) {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                        }
                    
                    if showTimestamp {
                        Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .onTapGesture {
                    HapticManager.shared.impact(.light)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showTimestamp.toggle()
                    }
                }
            }
        } else {
            // Assistant message full width
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 10) {
                    // Assistant avatar
                    Image("AppIconNoBg")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                        .opacity(0.8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Eris")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        
                        MessageView(content: message.content, isUser: false)
                            .contextMenu {
                                Button(action: {
                                    UIPasteboard.general.string = message.content
                                    HapticManager.shared.notification(.success)
                                }) {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                            }
                    }
                    
                    Spacer()
                }
                
                if showTimestamp {
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 38)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .onTapGesture {
                HapticManager.shared.impact(.light)
                withAnimation(.easeInOut(duration: 0.2)) {
                    showTimestamp.toggle()
                }
            }
        }
    }
}

struct TypingIndicator: View {
    let text: String
    @State private var animationAmount = 0.0
    
    private var isGeneratingCodeBlock: Bool {
        // Check if we have an unclosed code block
        let codeBlockStarts = text.components(separatedBy: "```").count - 1
        return codeBlockStarts % 2 == 1
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                // Assistant avatar
                Image("AppIconNoBg")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .opacity(0.8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Eris")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    if text.isEmpty {
                        // Dots animation
                        HStack(spacing: 4) {
                            ForEach(0..<3) { index in
                                Circle()
                                    .fill(Color.gray)
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(animationAmount)
                                    .opacity(animationAmount)
                                    .animation(
                                        .easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(index) * 0.2),
                                        value: animationAmount
                                    )
                            }
                        }
                        .padding(.vertical, 8)
                        .onAppear {
                            animationAmount = 1.0
                        }
                    } else if isGeneratingCodeBlock {
                        // Show code generation indicator
                        VStack(alignment: .leading, spacing: 8) {
                            // Show the text before the code block
                            if let lastCodeBlockRange = text.range(of: "```", options: .backwards) {
                                let textBeforeCode = String(text[..<lastCodeBlockRange.lowerBound])
                                if !textBeforeCode.isEmpty {
                                    MessageView(content: textBeforeCode, isUser: false)
                                }
                            }
                            
                            // Code generation indicator
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left.forwardslash.chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Generating code...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                    } else {
                        // Streaming text
                        MessageView(content: text, isUser: false)
                    }
                }
                
                Spacer()
            }
        }
    }
}

struct ChatInputView: View {
    @Binding var text: String
    let isGenerating: Bool
    let isLoadingModel: Bool
    let onSend: () -> Void
    let onStop: () -> Void
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Message", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 17))
                .padding(.vertical, 12)
                .lineLimit(1...5)
                .disabled(isGenerating)
                .onSubmit {
                    if !text.isEmpty && !isGenerating {
                        onSend()
                    }
                }
                .frame(minHeight: 24)
            
            if isGenerating {
                if isLoadingModel {
                    // Show loading indicator when model is loading
                    ProgressView()
                        .frame(width: 32, height: 32)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    // Show stop button when generating text
                    Button(action: {
                        HapticManager.shared.impact(.medium)
                        onStop()
                    }) {
                        Image(systemName: "stop.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                            .foregroundStyle(Color.red.opacity(0.8))
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            } else {
                Button(action: {
                    HapticManager.shared.impact(.light)
                    onSend()
                }) {
                    if #available(iOS 26.0, *) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 32, height: 32)
                            .foregroundStyle(text.isEmpty ? Color.gray : Color(UIColor.label))
                            .glassEffect(.regular.interactive(), in: .circle)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                            .foregroundStyle(text.isEmpty ? Color.gray : Color(UIColor.label))
                    }
                }
                .disabled(text.isEmpty)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

struct EmptyChatView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image("AppIconNoBg")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .opacity(0.3)
            
            VStack(spacing: 8) {
                Text("Start a conversation")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text("Type a message below to begin")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        let thread = Thread()
        // Add sample messages
        thread.addMessage(Message(content: "What is Eris?", role: .user))
        thread.addMessage(Message(content: """
            Eris is a privacy-focused AI chat application for iOS that runs entirely on your device. Here are its key features:
            
            **Core Features:**
            - 🔒 100% Private - All conversations stay on your device
            - 🚀 Hardware-accelerated using Apple Silicon and MLX framework
            - 📡 Works completely offline without internet connection
            - 🤖 Supports multiple open-source models (Llama, Qwen, Mistral, etc.)
            
            **Technical Details:**
            - Built with SwiftUI for a native iOS experience
            - Uses SwiftData for local data persistence
            - Requires iPhone/iPad with A12 Bionic chip or newer
            - Models are downloaded from Hugging Face and cached locally
            
            **Privacy Guarantee:**
            - No telemetry or analytics
            - No network requests except for initial model downloads
            - Full data deletion available in settings
            - Your conversations never leave your device
            
            Eris challenges the notion that AI must live in the cloud, bringing powerful language models directly to your pocket while maintaining complete privacy.
            """, role: .assistant))
        
        return ChatView(thread: thread)
            .modelContainer(for: [Thread.self, Message.self], inMemory: true)
    }
}