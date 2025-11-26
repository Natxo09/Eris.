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
    
    var body: some View {
        if isUser {
            // User messages with bubble
            if #available(iOS 26.0, *) {
                Text(content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .foregroundStyle(Color(UIColor.label))
                    .glassEffect(.regular, in: .capsule)
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
            MarkdownMessageView(content: content)
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
                    Text(block.content)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                case .header1:
                    Text(block.content)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .padding(.top, 8)
                case .header2:
                    Text(block.content)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .padding(.top, 6)
                case .header3:
                    Text(block.content)
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
        case bulletPoint
        case numberedList
        case code
        case codeBlock
    }
}

#Preview {
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
            """,
            isUser: false
        )
    }
    .padding()
}