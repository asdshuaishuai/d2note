import Foundation

struct FormatError: Error {
    let message: String
}

enum Formatter {

    // MARK: - JSON

    static func formatJSON(_ source: String, minify: Bool = false) -> Result<String, FormatError> {
        guard let data = source.data(using: .utf8) else {
            return .failure(FormatError(message: "无法以 UTF-8 读取内容"))
        }
        do {
            let obj = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            let options: JSONSerialization.WritingOptions = minify ? [.fragmentsAllowed] : [.prettyPrinted, .fragmentsAllowed, .withoutEscapingSlashes]
            let out = try JSONSerialization.data(withJSONObject: obj, options: options)
            return .success(String(decoding: out, as: UTF8.self))
        } catch {
            let desc = (error as NSError).userInfo[NSLocalizedDescriptionKey] as? String ?? error.localizedDescription
            return .failure(FormatError(message: desc))
        }
    }

    // MARK: - XML / HTML

    static func formatXML(_ source: String) -> Result<String, FormatError> {
        do {
            let doc = try XMLDocument(xmlString: source, options: [.documentIncludeContentTypeDeclaration])
            let out = doc.xmlString(options: [.nodePrettyPrint])
            return .success(out)
        } catch {
            // Fall back to plain re-indent for sloppy HTML.
            let desc = (error as NSError).userInfo[NSLocalizedDescriptionKey] as? String ?? "XML 解析失败"
            return .failure(FormatError(message: desc))
        }
    }

    // MARK: - Generic smart indent (brace-based languages)

    static func smartIndent(_ source: String, language: SourceLanguage, indentWidth: Int) -> String {
        let unit = String(repeating: " ", count: indentWidth)
        var lines = source.components(separatedBy: "\n")
        // Keep \r if CRLF: components split on \n leaves \r at end; strip for processing is fine since
        // NSTextView normally normalizes to \n.

        if language.usesBraceIndent {
            let closers: Set<Character> = ["}", "]"]
            var depth = 0
            var result: [String] = []
            result.reserveCapacity(lines.count)

            for line in lines {
                let trimmedLeading = line.drop { $0 == " " || $0 == "\t" }
                let t = trimmedLeading.trimmingCharacters(in: .whitespaces)
                var thisDepth = depth
                if let first = t.first, closers.contains(first) {
                    thisDepth = max(0, depth - 1)
                }
                result.append(String(repeating: unit, count: thisDepth) + t)
                depth = max(0, depth + bracketDelta(in: t))
            }
            lines = result
        }
        return lines.joined(separator: "\n")
    }

    /// Count net braces in one line, skipping quoted regions. Only { } [ ] counted.
    private static func bracketDelta(in line: String) -> Int {
        var delta = 0
        var inString: Character? = nil
        var escaped = false
        var prev: Character = " "
        for ch in line {
            if escaped { escaped = false; prev = ch; continue }
            if let q = inString {
                if ch == "\\" && (q == "\"" || q == "`") { escaped = true; prev = ch; continue }
                if ch == q { inString = nil }
                prev = ch
                continue
            }
            if ch == "\"" || ch == "'" || ch == "`" {
                // don't treat apostrophes in words as quotes
                if ch == "'" && (prev.isLetter || prev.isNumber) { prev = ch; continue }
                inString = ch
                prev = ch
                continue
            }
            if ch == "{" || ch == "[" { delta += 1 }
            if ch == "}" || ch == "]" { delta -= 1 }
            prev = ch
        }
        return delta
    }

    // MARK: - Trailing whitespace

    static func trimTrailingWhitespace(_ source: String) -> String {
        source
            .components(separatedBy: "\n")
            .map { line -> String in
                var s = Substring(line)
                while let last = s.last, last == " " || last == "\t" { s = s.dropLast() }
                return String(s)
            }
            .joined(separator: "\n")
    }

    // MARK: - Line / text utilities (快速格式化)

    static func mapLines(_ source: String, _ f: ([String]) -> [String]) -> String {
        f(source.components(separatedBy: "\n")).joined(separator: "\n")
    }

    static func sortLines(_ source: String, reverse: Bool) -> String {
        mapLines(source) { lines in
            var sorted = lines.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            if reverse { sorted.reverse() }
            return sorted
        }
    }

    static func reverseLines(_ source: String) -> String {
        mapLines(source) { $0.reversed() }
    }

    static func dedupeLines(_ source: String) -> String {
        mapLines(source) { lines in
            var seen = Set<String>()
            var out: [String] = []
            for line in lines {
                if seen.contains(line) { continue }
                seen.insert(line)
                out.append(line)
            }
            return out
        }
    }

    static func removeEmptyLines(_ source: String) -> String {
        mapLines(source) { $0.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty } }
    }

    static func tabsToSpaces(_ source: String, width: Int) -> String {
        source.replacingOccurrences(of: "\t", with: String(repeating: " ", count: max(1, width)))
    }

    /// 压缩 XML/HTML：去除标签之间的空白（可能合并文本节点空白）。
    static func minifyXMLHTML(_ source: String) -> String {
        var s = source.replacingOccurrences(of: ">\\s+<", with: "><", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?m)^[ \\t]+", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "\n{2,}", with: "\n", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 轻量 SQL 美化：主要子句换行 + 关键字大写（字符串字面量原样保留）。
    static func beautifySQL(_ source: String) -> String {
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return source }

        // 1. 抽出单引号字符串字面量，避免被改写
        var literals: [String] = []
        var work = ""
        var cur = ""
        var inString = false
        for ch in source {
            if ch == "'" {
                cur.append(ch)
                if inString {
                    literals.append(cur)
                    work += "\u{E000}\(literals.count - 1)\u{E001}"
                    cur = ""
                }
                inString.toggle()
                continue
            }
            if inString { cur.append(ch) } else { work.append(ch) }
        }
        work += cur

        // 2. 主要子句前换行（关键字大写）
        let clauses = [
            "INSERT INTO", "DELETE FROM", "LEFT OUTER JOIN", "RIGHT OUTER JOIN",
            "LEFT JOIN", "RIGHT JOIN", "INNER JOIN", "FULL JOIN", "CROSS JOIN",
            "GROUP BY", "ORDER BY", "UNION ALL", "UNION", "SELECT", "FROM",
            "WHERE", "HAVING", "LIMIT", "OFFSET", "VALUES", "SET", "UPDATE", "JOIN",
        ]
        for clause in clauses {
            work = work.replacingOccurrences(
                of: "\\b\(clause)\\b",
                with: "\n\(clause) ",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        // 3. 其余常见关键字大写
        let keywords = ["AND", "OR", "ON", "AS", "IN", "NOT", "NULL", "IS", "LIKE",
                        "BETWEEN", "DISTINCT", "ASC", "DESC", "CASE", "WHEN", "THEN",
                        "ELSE", "END", "COUNT", "SUM", "AVG", "MIN", "MAX", "EXISTS"]
        for kw in keywords {
            work = work.replacingOccurrences(
                of: "\\b\(kw)\\b",
                with: kw,
                options: [.regularExpression, .caseInsensitive]
            )
        }

        // 4. 清理换行产生的多余空白行，恢复字符串
        work = work.replacingOccurrences(of: "\n{2,}", with: "\n", options: .regularExpression)
        work = work.trimmingCharacters(in: .whitespacesAndNewlines)
        for (i, literal) in literals.enumerated() {
            work = work.replacingOccurrences(of: "\u{E000}\(i)\u{E001}", with: literal)
        }
        return work
    }
}
