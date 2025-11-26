//
//  MessageView.swift
//  Eris.
//
//  Created by Ignacio Palacio on 19/6/25.
//

import SwiftUI

struct MessageView: View {
    let content: String
    let isUser: Bool

    // Parse thinking content from message
    // Returns: (thinking content, response text, is streaming thinking)
    private var parsedContent: (thinking: String?, response: String, isStreaming: Bool) {
        parseThinkingContent(content)
    }

    var body: some View {
        if isUser {
            // User messages with bubble
            if #available(iOS 26.0, *) {
                Text(content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .foregroundStyle(Color(UIColor.label))
                    .glassEffect(.regular, in: .rect(cornerRadius: 18))
            } else {
                Text(content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.gray)
                    )
                    .foregroundStyle(.white)
            }
        } else {
            // Assistant messages without bubble, full width
            VStack(alignment: .leading, spacing: 12) {
                // Show thinking block if present (including during streaming)
                if let thinking = parsedContent.thinking {
                    ThinkingView(content: thinking, isStreaming: parsedContent.isStreaming)
                }

                // Show response
                if !parsedContent.response.isEmpty {
                    MarkdownMessageView(content: parsedContent.response)
                }
            }
        }
    }

    // Extract <think>...</think> content from message
    // Supports both closed tags and open tags (during streaming)
    // Returns: (thinking content, response text, is streaming)
    private func parseThinkingContent(_ text: String) -> (thinking: String?, response: String, isStreaming: Bool) {
        // First try to match closed <think>...</think> tags
        let closedPattern = #"<think>([\s\S]*?)</think>"#

        if let closedRegex = try? NSRegularExpression(pattern: closedPattern, options: []),
           let match = closedRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let thinkingRange = Range(match.range(at: 1), in: text) {

            var thinking = String(text[thinkingRange])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Clean any remaining tags
            thinking = thinking
                .replacingOccurrences(of: "<think>", with: "")
                .replacingOccurrences(of: "</think>", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Remove the entire <think>...</think> block from the response
            let response = closedRegex.stringByReplacingMatches(
                in: text,
                range: NSRange(text.startIndex..., in: text),
                withTemplate: ""
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            // Closed tag = not streaming
            return (thinking.isEmpty ? nil : thinking, response, false)
        }

        // If no closed tag, check for open <think> tag (streaming scenario)
        if let openTagRange = text.range(of: "<think>") {
            // Everything after <think> is thinking content (still in progress)
            var thinkingContent = String(text[openTagRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Clean any remaining tags
            thinkingContent = thinkingContent
                .replacingOccurrences(of: "<think>", with: "")
                .replacingOccurrences(of: "</think>", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Everything before <think> is the response (if any)
            let response = String(text[..<openTagRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Open tag without close = streaming
            return (thinkingContent.isEmpty ? "" : thinkingContent, response, true)
        }

        return (nil, text, false)
    }
}

// MARK: - Thinking View (Collapsible)
struct ThinkingView: View {
    let content: String
    var isStreaming: Bool = false
    @State private var isExpanded = false

    private var hasContent: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
                HapticManager.shared.selection()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(UIColor.secondaryLabel))

                    Text(isStreaming ? "Thinking..." : "Thinking")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color(UIColor.secondaryLabel))

                    if isStreaming {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(Color(UIColor.secondaryLabel))
                    }

                    Spacer()

                    if hasContent {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(UIColor.tertiaryLabel))
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
            }
            .buttonStyle(.plain)
            .disabled(!hasContent)

            // Expandable content
            if isExpanded && hasContent {
                Text(content)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(UIColor.tertiarySystemBackground))
                    )
                    .padding(.top, 8)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
    }
}

struct MarkdownMessageView: View {
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(parseMarkdown(content), id: \.id) { block in
                switch block.type {
                case .text:
                    Text(processInlineMarkdown(block.content))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                case .header1:
                    Text(processInlineMarkdown(block.content))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .padding(.top, 8)
                case .header2:
                    Text(processInlineMarkdown(block.content))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .padding(.top, 6)
                case .header3:
                    Text(processInlineMarkdown(block.content))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .padding(.top, 4)
                case .bold:
                    Text(block.content)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                case .italic:
                    Text(block.content)
                        .italic()
                        .foregroundStyle(.primary)
                case .bulletPoint:
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundStyle(.secondary)
                            .frame(width: 20, alignment: .leading)
                        Text(processInlineMarkdown(block.content))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                case .numberedList:
                    HStack(alignment: .top, spacing: 8) {
                        Text(block.metadata ?? "")
                            .foregroundStyle(.secondary)
                            .frame(width: 20, alignment: .leading)
                        Text(processInlineMarkdown(block.content))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                case .code:
                    Text(block.content)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.primary)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                case .codeBlock:
                    CodeBlockView(code: block.content, language: block.metadata)
                case .strikethrough:
                    Text(block.content)
                        .strikethrough()
                        .foregroundStyle(.secondary)
                case .table:
                    let tableLines = block.content.split(separator: "\n").map(String.init)
                    MarkdownTableView(tableData: MarkdownTable(from: tableLines))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // Simple markdown parser
    private func parseMarkdown(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var i = 0
        var inCodeBlock = false
        var codeBlockContent = ""
        var codeBlockLanguage: String?

        // Helper to check if a line is a table row
        func isTableLine(_ line: String) -> Bool {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.starts(with: "|") && trimmed.contains("|")
        }

        while i < lines.count {
            let line = String(lines[i])

            // Check for code block
            if line.starts(with: "```") {
                if inCodeBlock {
                    // End code block
                    if !codeBlockContent.isEmpty {
                        // Process code block content to handle long first-line comments
                        let processedContent = processCodeBlockContent(codeBlockContent, language: codeBlockLanguage)
                        blocks.append(MarkdownBlock(
                            type: .codeBlock,
                            content: processedContent,
                            metadata: codeBlockLanguage
                        ))
                    }
                    codeBlockContent = ""
                    codeBlockLanguage = nil
                    inCodeBlock = false
                } else {
                    // Start code block
                    inCodeBlock = true
                    codeBlockLanguage = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    if codeBlockLanguage?.isEmpty == true {
                        codeBlockLanguage = nil
                    }
                }
                i += 1
                continue
            }

            if inCodeBlock {
                codeBlockContent += line + "\n"
                i += 1
                continue
            }

            // Check for table (consecutive lines starting with |)
            if isTableLine(line) {
                var tableLines: [String] = [line]
                i += 1
                while i < lines.count && isTableLine(String(lines[i])) {
                    tableLines.append(String(lines[i]))
                    i += 1
                }
                blocks.append(MarkdownBlock(
                    type: .table,
                    content: tableLines.joined(separator: "\n")
                ))
                continue
            }

            // Headers
            if line.starts(with: "### ") {
                blocks.append(MarkdownBlock(type: .header3, content: String(line.dropFirst(4))))
            } else if line.starts(with: "## ") {
                blocks.append(MarkdownBlock(type: .header2, content: String(line.dropFirst(3))))
            } else if line.starts(with: "# ") {
                blocks.append(MarkdownBlock(type: .header1, content: String(line.dropFirst(2))))
            }
            // Bullet points (check before bold text)
            else if line.starts(with: "- ") || line.starts(with: "* ") {
                blocks.append(MarkdownBlock(type: .bulletPoint, content: String(line.dropFirst(2))))
            }
            // Numbered lists (check before bold text)
            else if let match = line.firstMatch(of: /^(\d+)\.\s+(.*)/) {
                let number = String(match.1)
                let content = String(match.2)
                blocks.append(MarkdownBlock(type: .numberedList, content: content, metadata: number + "."))
            }
            // Strikethrough text
            else if line.contains("~~") {
                let parts = line.split(separator: "~~", omittingEmptySubsequences: false)
                for (index, part) in parts.enumerated() {
                    if index % 2 == 1 {
                        blocks.append(MarkdownBlock(type: .strikethrough, content: String(part)))
                    } else if !part.isEmpty {
                        blocks.append(MarkdownBlock(type: .text, content: String(part)))
                    }
                }
            }
            // Bold text
            else if line.contains("**") {
                let parts = line.split(separator: "**")
                for (index, part) in parts.enumerated() {
                    if index % 2 == 1 {
                        blocks.append(MarkdownBlock(type: .bold, content: String(part)))
                    } else if !part.isEmpty {
                        blocks.append(MarkdownBlock(type: .text, content: String(part)))
                    }
                }
            }
            // Inline code
            else if line.contains("`") && !line.starts(with: "```") {
                let parts = line.split(separator: "`")
                for (index, part) in parts.enumerated() {
                    if index % 2 == 1 {
                        blocks.append(MarkdownBlock(type: .code, content: String(part)))
                    } else if !part.isEmpty {
                        blocks.append(MarkdownBlock(type: .text, content: String(part)))
                    }
                }
            }
            // Regular text
            else if !line.isEmpty {
                blocks.append(MarkdownBlock(type: .text, content: line))
            }
            
            i += 1
        }
        
        return blocks.isEmpty ? [MarkdownBlock(type: .text, content: text)] : blocks
    }
    
    // Process code block content to wrap long first-line comments
    private func processCodeBlockContent(_ content: String, language: String?) -> String {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard !lines.isEmpty else { return content }
        
        // Check if first line is a very long comment
        let firstLine = lines[0]
        let isComment = firstLine.starts(with: "#") || firstLine.starts(with: "//") || firstLine.starts(with: "/*")
        
        if isComment && firstLine.count > 80 {
            // Wrap long first-line comments
            var wrappedLines: [String] = []
            let words = firstLine.split(separator: " ")
            var currentLine = ""
            let commentPrefix = firstLine.starts(with: "#") ? "# " : (firstLine.starts(with: "//") ? "// " : "/* ")
            
            for word in words {
                if currentLine.isEmpty {
                    currentLine = String(word)
                } else if (currentLine + " " + word).count <= 80 {
                    currentLine += " " + String(word)
                } else {
                    wrappedLines.append(currentLine)
                    currentLine = commentPrefix + String(word)
                }
            }
            if !currentLine.isEmpty {
                wrappedLines.append(currentLine)
            }
            
            // Add the rest of the lines
            if lines.count > 1 {
                wrappedLines.append(contentsOf: lines[1...])
            }
            
            return wrappedLines.joined(separator: "\n")
        }
        
        return content
    }
    
    // Process inline markdown formatting for list items
    private func processInlineMarkdown(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        
        // Handle bold text (**text**)
        do {
            let boldPattern = #"\*\*([^*]+)\*\*"#
            let boldRegex = try NSRegularExpression(pattern: boldPattern)
            let nsString = text as NSString
            let matches = boldRegex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            
            for match in matches.reversed() {
                let matchRange = match.range(at: 1)
                if let swiftRange = Range(matchRange, in: text),
                   let attributedRange = Range(match.range, in: result) {
                    let boldText = String(text[swiftRange])
                    var replacement = AttributedString(boldText)
                    replacement.font = .body.bold()
                    result.replaceSubrange(attributedRange, with: replacement)
                }
            }
        } catch {}
        
        // Handle italic text (*text*)
        do {
            let italicPattern = #"(?<!\*)\*([^*]+)\*(?!\*)"#
            let italicRegex = try NSRegularExpression(pattern: italicPattern)
            let nsString = result.description as NSString
            let matches = italicRegex.matches(in: result.description, range: NSRange(location: 0, length: nsString.length))
            
            for match in matches.reversed() {
                let matchRange = match.range(at: 1)
                if let swiftRange = Range(matchRange, in: result.description),
                   let attributedRange = Range(match.range, in: result) {
                    let italicText = String(result.description[swiftRange])
                    var replacement = AttributedString(italicText)
                    replacement.font = .body.italic()
                    result.replaceSubrange(attributedRange, with: replacement)
                }
            }
        } catch {}
        
        // Handle inline code (`code`)
        do {
            let codePattern = #"`([^`]+)`"#
            let codeRegex = try NSRegularExpression(pattern: codePattern)
            let nsString = result.description as NSString
            let matches = codeRegex.matches(in: result.description, range: NSRange(location: 0, length: nsString.length))

            for match in matches.reversed() {
                let matchRange = match.range(at: 1)
                if let swiftRange = Range(matchRange, in: result.description),
                   let attributedRange = Range(match.range, in: result) {
                    let codeText = String(result.description[swiftRange])
                    var replacement = AttributedString(codeText)
                    replacement.font = .system(.body, design: .monospaced)
                    replacement.backgroundColor = Color.gray.opacity(0.1)
                    result.replaceSubrange(attributedRange, with: replacement)
                }
            }
        } catch {}

        // Handle strikethrough (~~text~~)
        do {
            let strikethroughPattern = #"~~([^~]+)~~"#
            let strikethroughRegex = try NSRegularExpression(pattern: strikethroughPattern)
            let nsString = result.description as NSString
            let matches = strikethroughRegex.matches(in: result.description, range: NSRange(location: 0, length: nsString.length))

            for match in matches.reversed() {
                let matchRange = match.range(at: 1)
                if let swiftRange = Range(matchRange, in: result.description),
                   let attributedRange = Range(match.range, in: result) {
                    let strikeText = String(result.description[swiftRange])
                    var replacement = AttributedString(strikeText)
                    replacement.strikethroughStyle = .single
                    replacement.foregroundColor = .secondary
                    result.replaceSubrange(attributedRange, with: replacement)
                }
            }
        } catch {}

        // Handle markdown links ([text](url))
        do {
            let linkPattern = #"\[([^\]]+)\]\(([^)]+)\)"#
            let linkRegex = try NSRegularExpression(pattern: linkPattern)
            let nsString = result.description as NSString
            let matches = linkRegex.matches(in: result.description, range: NSRange(location: 0, length: nsString.length))

            for match in matches.reversed() {
                let textRange = match.range(at: 1)
                let urlRange = match.range(at: 2)
                if let swiftTextRange = Range(textRange, in: result.description),
                   let swiftUrlRange = Range(urlRange, in: result.description),
                   let attributedRange = Range(match.range, in: result) {
                    let linkText = String(result.description[swiftTextRange])
                    let urlString = String(result.description[swiftUrlRange])

                    var replacement = AttributedString(linkText)
                    if let url = URL(string: urlString) {
                        replacement.link = url
                        replacement.foregroundColor = .blue
                        replacement.underlineStyle = .single
                    }
                    result.replaceSubrange(attributedRange, with: replacement)
                }
            }
        } catch {}

        // Handle plain URLs (https://... or http://...)
        do {
            let urlPattern = #"(https?://[^\s\]\)<>]+)"#
            let urlRegex = try NSRegularExpression(pattern: urlPattern)
            let currentString = String(result.characters)
            let nsString = currentString as NSString
            let matches = urlRegex.matches(in: currentString, range: NSRange(location: 0, length: nsString.length))

            for match in matches.reversed() {
                if let swiftRange = Range(match.range, in: currentString),
                   let attributedRange = Range(match.range, in: result) {
                    let urlString = String(currentString[swiftRange])

                    var replacement = AttributedString(urlString)
                    if let url = URL(string: urlString) {
                        replacement.link = url
                        replacement.foregroundColor = .blue
                        replacement.underlineStyle = .single
                    }
                    result.replaceSubrange(attributedRange, with: replacement)
                }
            }
        } catch {}

        return result
    }
}

struct MarkdownBlock: Identifiable {
    let id = UUID()
    let type: BlockType
    let content: String
    var metadata: String? = nil
    
    enum BlockType {
        case text
        case header1
        case header2
        case header3
        case bold
        case italic
        case strikethrough
        case bulletPoint
        case numberedList
        case code
        case codeBlock
        case table
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            MessageView(
                content: "Hello, this is a user message",
                isUser: true
            )

            MessageView(
                content: """
                **Verificación de Instalación**

                Primero, asegúrate de tener Homebrew instalado:

                ```bash
                # Instala Homebrew
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                ```

                **Instalación de Python**

                1. Abre Terminal
                2. Ejecuta el comando: `brew install python3`
                3. Verifica la instalación: `python3 --version`

                - Python 3.x es recomendado
                - Incluye pip para gestionar paquetes
                - Compatible con virtual environments

                ~~Este texto está tachado~~

                Visita [Apple](https://apple.com) para más información.

                | Comando | Descripción |
                |---------|-------------|
                | `ls` | Lista archivos |
                | `cd` | Cambia directorio |
                | `pwd` | Muestra ruta actual |
                """,
                isUser: false
            )
        }
        .padding()
    }
}