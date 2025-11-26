//
//  MarkdownTableView.swift
//  Eris.
//
//  Created by Ignacio Palacio on 26/11/25.
//

import SwiftUI

// MARK: - Table Data Structure
struct MarkdownTable {
    let headers: [String]
    let rows: [[String]]
    let columnCount: Int

    init(from lines: [String]) {
        var headers: [String] = []
        var rows: [[String]] = []

        for (index, line) in lines.enumerated() {
            let cells = line
                .trimmingCharacters(in: .whitespaces)
                .split(separator: "|")
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            // Skip separator line (contains only dashes and colons)
            if cells.allSatisfy({ $0.allSatisfy { $0 == "-" || $0 == ":" } }) {
                continue
            }

            if index == 0 {
                headers = cells
            } else {
                rows.append(cells)
            }
        }

        self.headers = headers
        self.rows = rows
        self.columnCount = headers.count
    }
}

// MARK: - Table View
struct MarkdownTableView: View {
    let tableData: MarkdownTable

    // Calculate column width based on content
    private func columnWidth(for columnIndex: Int) -> CGFloat {
        var maxLength = tableData.headers[safe: columnIndex]?.count ?? 0

        for row in tableData.rows {
            if let cell = row[safe: columnIndex] {
                maxLength = max(maxLength, cell.count)
            }
        }

        // Min 100, max 200, scale based on content
        let calculated = CGFloat(maxLength * 10 + 24)
        return min(max(calculated, 100), 200)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(alignment: .top, spacing: 0) {
                    ForEach(tableData.headers.indices, id: \.self) { index in
                        TableCellView(
                            content: tableData.headers[index],
                            isHeader: true
                        )
                        .frame(width: columnWidth(for: index), alignment: .leading)

                        if index < tableData.headers.count - 1 {
                            Rectangle()
                                .fill(Color(UIColor.separator).opacity(0.3))
                                .frame(width: 1)
                        }
                    }
                }
                .background(Color(UIColor.secondarySystemBackground))

                // Separator
                Rectangle()
                    .fill(Color(UIColor.separator))
                    .frame(height: 1)

                // Data rows
                ForEach(tableData.rows.indices, id: \.self) { rowIndex in
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(tableData.headers.indices, id: \.self) { colIndex in
                            let cellContent = tableData.rows[rowIndex][safe: colIndex] ?? ""
                            TableCellView(
                                content: cellContent,
                                isHeader: false
                            )
                            .frame(width: columnWidth(for: colIndex), alignment: .leading)

                            if colIndex < tableData.headers.count - 1 {
                                Rectangle()
                                    .fill(Color(UIColor.separator).opacity(0.3))
                                    .frame(width: 1)
                            }
                        }
                    }

                    if rowIndex < tableData.rows.count - 1 {
                        Rectangle()
                            .fill(Color(UIColor.separator).opacity(0.5))
                            .frame(height: 0.5)
                    }
                }
            }
            .background(Color(UIColor.tertiarySystemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(UIColor.separator), lineWidth: 0.5)
            )
        }
    }
}

// MARK: - Table Cell View
struct TableCellView: View {
    let content: String
    let isHeader: Bool

    var body: some View {
        Text(processInlineMarkdown(content))
            .font(.subheadline)
            .fontWeight(isHeader ? .semibold : .regular)
            .foregroundStyle(.primary)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
    }

    // Process inline markdown (bold, italic, code, strikethrough)
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
                    replacement.font = .subheadline.bold()
                    result.replaceSubrange(attributedRange, with: replacement)
                }
            }
        } catch {}

        // Handle inline code (`code`)
        do {
            let codePattern = #"`([^`]+)`"#
            let codeRegex = try NSRegularExpression(pattern: codePattern)
            let currentString = String(result.characters)
            let nsString = currentString as NSString
            let matches = codeRegex.matches(in: currentString, range: NSRange(location: 0, length: nsString.length))

            for match in matches.reversed() {
                let matchRange = match.range(at: 1)
                if let swiftRange = Range(matchRange, in: currentString),
                   let attributedRange = Range(match.range, in: result) {
                    let codeText = String(currentString[swiftRange])
                    var replacement = AttributedString(codeText)
                    replacement.font = .system(.caption, design: .monospaced)
                    replacement.backgroundColor = Color.gray.opacity(0.15)
                    result.replaceSubrange(attributedRange, with: replacement)
                }
            }
        } catch {}

        return result
    }
}

// MARK: - Safe Array Access
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            MarkdownTableView(tableData: MarkdownTable(from: [
                "| Comando | Descripción | Ejemplo |",
                "|---------|-------------|---------|",
                "| `ls` | **Lista archivos** del directorio actual | ls -la |",
                "| `cd` | Cambia de directorio | cd /home |",
                "| `pwd` | Muestra la ruta actual del directorio de trabajo | pwd |"
            ]))

            MarkdownTableView(tableData: MarkdownTable(from: [
                "| Nombre | Edad |",
                "|--------|------|",
                "| Juan | 25 |",
                "| María | 30 |"
            ]))
        }
        .padding()
    }
}
