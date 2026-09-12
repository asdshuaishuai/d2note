import AppKit
import Foundation

enum SourceLanguage: String, CaseIterable {
    case plain = "Plain Text"
    case swift = "Swift"
    case python = "Python"
    case javascript = "JavaScript"
    case typescript = "TypeScript"
    case c = "C"
    case cpp = "C++"
    case csharp = "C#"
    case java = "Java"
    case go = "Go"
    case rust = "Rust"
    case ruby = "Ruby"
    case php = "PHP"
    case json = "JSON"
    case xml = "XML"
    case html = "HTML"
    case css = "CSS"
    case markdown = "Markdown"
    case yaml = "YAML"
    case shell = "Shell"
    case sql = "SQL"

    var displayName: String { rawValue }

    static func fromDisplayName(_ name: String) -> SourceLanguage? {
        allCases.first { $0.displayName == name }
    }

    /// Auto-detect language from file extension, falling back to content sniffing.
    static func detect(url: URL?, content: String) -> SourceLanguage {
        if let ext = url?.pathExtension.lowercased(), !ext.isEmpty,
           let lang = extensionMap[ext] {
            return lang
        }
        return detectFromContent(content)
    }

    static func detectFromContent(_ content: String) -> SourceLanguage {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .plain }
        let firstLine = trimmed.components(separatedBy: .newlines).first ?? ""

        // Shebang
        if firstLine.hasPrefix("#!") {
            if firstLine.contains("python") { return .python }
            if firstLine.contains("ruby") { return .ruby }
            if firstLine.contains("php") { return .php }
            if firstLine.contains("node") { return .javascript }
            return .shell
        }
        if firstLine.hasPrefix("<?xml") { return .xml }
        if firstLine.lowercased().hasPrefix("<!doctype html") || trimmed.lowercased().hasPrefix("<html") { return .html }

        if (trimmed.hasPrefix("{") || trimmed.hasPrefix("[")),
           content.utf16.count < 1_000_000,
           let data = trimmed.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil {
            return .json
        }
        if trimmed.hasPrefix("---") && !trimmed.contains("{") { return .yaml }

        if trimmed.contains("import SwiftUI") || (trimmed.contains("import Foundation") && trimmed.contains("func ") && trimmed.contains("let ")) { return .swift }
        if trimmed.contains("package main") { return .go }
        if trimmed.contains("fn main()") { return .rust }
        if trimmed.contains("#include") { return trimmed.contains("std::") || trimmed.contains("cout") ? .cpp : .c }
        if trimmed.contains("using System;") { return .csharp }
        if trimmed.contains("public static void main") { return .java }
        if trimmed.contains("<?php") { return .php }
        if firstLine.hasPrefix("def ") || trimmed.contains("\ndef ") { return .python }
        if trimmed.contains("function ") || trimmed.hasPrefix("const ") || trimmed.hasPrefix("let ") { return .javascript }
        if trimmed.contains("interface ") || trimmed.contains(": string") || trimmed.contains(": number") { return .typescript }
        if firstLine.uppercased().hasPrefix("SELECT") && trimmed.uppercased().contains("FROM") { return .sql }
        return .plain
    }

    static let extensionMap: [String: SourceLanguage] = [
        "swift": .swift,
        "py": .python, "pyw": .python,
        "js": .javascript, "mjs": .javascript, "cjs": .javascript, "jsx": .javascript,
        "ts": .typescript, "tsx": .typescript,
        "c": .c, "h": .c,
        "cpp": .cpp, "cc": .cpp, "cxx": .cpp, "hpp": .cpp, "hh": .cpp, "hxx": .cpp,
        "m": .c, "mm": .cpp,
        "cs": .csharp,
        "java": .java,
        "go": .go,
        "rs": .rust,
        "rb": .ruby, "erb": .ruby,
        "php": .php,
        "json": .json, "jsonc": .json, "json5": .json,
        "xml": .xml, "svg": .xml, "xib": .xml, "storyboard": .xml, "plist": .xml, "xsl": .xml, "xsd": .xml,
        "html": .html, "htm": .html, "vue": .html,
        "css": .css, "scss": .css, "less": .css,
        "md": .markdown, "markdown": .markdown,
        "yaml": .yaml, "yml": .yaml,
        "sh": .shell, "bash": .shell, "zsh": .shell, "command": .shell,
        "sql": .sql,
        "txt": .plain, "text": .plain, "log": .plain, "csv": .plain, "tsv": .plain,
        "toml": .yaml, "ini": .yaml, "cfg": .plain, "conf": .plain, "env": .yaml,
        "gitignore": .plain, "gitattributes": .plain, "editorconfig": .yaml,
    ]
}


// MARK: - File-type badge (tab icons)

extension SourceLanguage {
    /// GitHub-Linguist-inspired color per language.
    var badgeColor: NSColor {
        switch self {
        case .swift:      return NSColor(srgbRed: 0.941, green: 0.318, blue: 0.220, alpha: 1) // #F05138
        case .python:     return NSColor(srgbRed: 0.208, green: 0.447, blue: 0.647, alpha: 1) // #3572A5
        case .javascript: return NSColor(srgbRed: 0.945, green: 0.878, blue: 0.353, alpha: 1) // #F1E05A
        case .typescript: return NSColor(srgbRed: 0.192, green: 0.471, blue: 0.776, alpha: 1) // #3178C6
        case .c:          return NSColor(srgbRed: 0.659, green: 0.725, blue: 0.800, alpha: 1) // #A8B9CC
        case .cpp:        return NSColor(srgbRed: 0.953, green: 0.294, blue: 0.490, alpha: 1) // #F34B7D
        case .csharp:     return NSColor(srgbRed: 0.094, green: 0.525, blue: 0.000, alpha: 1) // #178600
        case .java:       return NSColor(srgbRed: 0.690, green: 0.447, blue: 0.098, alpha: 1) // #B07219
        case .go:         return NSColor(srgbRed: 0.000, green: 0.678, blue: 0.847, alpha: 1) // #00ADD8
        case .rust:       return NSColor(srgbRed: 0.808, green: 0.482, blue: 0.345, alpha: 1) // #CE7B58
        case .ruby:       return NSColor(srgbRed: 0.800, green: 0.204, blue: 0.176, alpha: 1) // #CC342D
        case .php:        return NSColor(srgbRed: 0.310, green: 0.365, blue: 0.584, alpha: 1) // #4F5D95
        case .json:       return NSColor(srgbRed: 0.796, green: 0.796, blue: 0.255, alpha: 1) // #CBCB41
        case .xml:        return NSColor(srgbRed: 0.000, green: 0.376, blue: 0.675, alpha: 1) // #0060AC
        case .html:       return NSColor(srgbRed: 0.890, green: 0.298, blue: 0.149, alpha: 1) // #E34C26
        case .css:        return NSColor(srgbRed: 0.337, green: 0.239, blue: 0.486, alpha: 1) // #563D7C
        case .markdown:   return NSColor(srgbRed: 0.031, green: 0.247, blue: 0.631, alpha: 1) // #083FA1
        case .yaml:       return NSColor(srgbRed: 0.796, green: 0.090, blue: 0.118, alpha: 1) // #CB171E
        case .shell:      return NSColor(srgbRed: 0.537, green: 0.878, blue: 0.318, alpha: 1) // #89E051
        case .sql:        return NSColor(srgbRed: 0.890, green: 0.549, blue: 0.000, alpha: 1) // #E38C00
        case .plain:      return NSColor(srgbRed: 0.545, green: 0.580, blue: 0.620, alpha: 1) // #8B949E
        }
    }

    /// Short badge label drawn inside the 16pt icon.
    var badgeLabel: String {
        switch self {
        case .swift: return "SW"
        case .python: return "PY"
        case .javascript: return "JS"
        case .typescript: return "TS"
        case .c: return "C"
        case .cpp: return "C++"
        case .csharp: return "C#"
        case .java: return "JV"
        case .go: return "GO"
        case .rust: return "RS"
        case .ruby: return "RB"
        case .php: return "PHP"
        case .json: return "{}"
        case .xml: return "XML"
        case .html: return "<>"
        case .css: return "CSS"
        case .markdown: return "MD"
        case .yaml: return "YML"
        case .shell: return "$"
        case .sql: return "SQL"
        case .plain: return "TX"
        }
    }

    /// White on dark badges, near-black on light ones (contrast rule).
    var badgeTextColor: NSColor {
        let c = badgeColor.usingColorSpace(.sRGB) ?? .white
        let lum = 0.2126 * c.redComponent + 0.7152 * c.greenComponent + 0.0722 * c.blueComponent
        return lum > 0.55 ? NSColor(white: 0.12, alpha: 1) : .white
    }
}
