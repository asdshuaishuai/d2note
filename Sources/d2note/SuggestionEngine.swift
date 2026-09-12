import Foundation
import NaturalLanguage

/// On-device habit learning: records lines/words the user types and suggests
/// line completions (ghost text) or word completions. Everything stays local
/// (stored in UserDefaults), and the whole engine is opt-in (default off).
final class SuggestionEngine {

    static let shared = SuggestionEngine()
    private init() { load() }

    /// prefix(≤8 chars of trimmed line) -> full line -> count
    private var lineIndex: [String: [String: Int]] = [:]
    private var wordStats: [String: Int] = [:]
    private var recordsSinceSave = 0

    // MARK: - Learning

    func record(line raw: String) {
        let line = raw.trimmingCharacters(in: .whitespaces)
        let n = line.utf16.count
        guard n >= 2, n <= 160 else { return }
        if line.contains("://") { return }                       // URLs are noise
        if line.range(of: "^[0-9 .,;:!?()\\[\\]{}-]+$", options: .regularExpression) != nil { return }

        let key = String(line.prefix(8))
        var bucket = lineIndex[key] ?? [:]
        bucket[line, default: 0] += 1
        if bucket.count > 10 {
            bucket = Dictionary(uniqueKeysWithValues: bucket.sorted { $0.value > $1.value }.prefix(8).map { ($0.key, $0.value) })
        }
        lineIndex[key] = bucket
        if lineIndex.count > 800 { pruneLines() }
        recordWords(in: line)
        autosave()
    }

    /// Batch-learn every non-empty line of a document (menu action).
    func learn(_ text: String) {
        text.enumerateLines { line, _ in
            self.record(line: line)
        }
        save()
    }

    func clear() {
        lineIndex = [:]
        wordStats = [:]
        save()
    }

    var statsSummary: String {
        let lines = lineIndex.values.reduce(0) { $0 + $1.count }
        return "\(lines) 条短语 · \(wordStats.count) 个词"
    }

    // MARK: - Queries

    /// Suggest the remainder of a line given what has been typed (leading
    /// whitespace excluded). Returns text WITHOUT the typed prefix.
    func lineSuggestion(for typed: String) -> String? {
        let trimmed = typed.trimmingCharacters(in: .whitespaces)
        guard trimmed.utf16.count >= 2 else { return nil }
        let key = String(trimmed.prefix(8))
        guard let bucket = lineIndex[key] else { return nil }
        var best: (String, Int)?
        for (full, count) in bucket {
            guard full.hasPrefix(trimmed), full.utf16.count > trimmed.utf16.count else { continue }
            if best == nil || count > best!.1 { best = (full, count) }
        }
        guard let b = best else { return nil }
        return String(b.0.dropFirst(trimmed.utf16.count))
    }

    /// Word completion for the word prefix before the caret.
    func wordSuggestion(for prefix: String) -> String? {
        guard prefix.utf16.count >= 2 else { return nil }
        let lower = prefix.lowercased()
        var best: (String, Int)?
        for (word, count) in wordStats {
            if word.count > prefix.count, word.lowercased().hasPrefix(lower) {
                if best == nil || count > best!.1 { best = (word, count) }
            }
        }
        guard let b = best else { return nil }
        return String(b.0.dropFirst(prefix.count))
    }

    // MARK: - Private

    private func recordWords(in line: String) {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = line
        tokenizer.enumerateTokens(in: line.startIndex..<line.endIndex) { range, _ in
            let word = String(line[range])
            if word.count >= 3, word.count <= 24 {
                self.wordStats[word, default: 0] += 1
                if self.wordStats.count > 6000 { self.pruneWords() }
            }
            return true
        }
    }

    private func pruneLines() {
        // keep the 600 prefixes with the most total hits
        let ranked = lineIndex.sorted { ($0.value.values.reduce(0, +)) > ($1.value.values.reduce(0, +)) }.prefix(600)
        lineIndex = Dictionary(uniqueKeysWithValues: ranked.map { ($0.key, $0.value) })
    }

    private func pruneWords() {
        wordStats = Dictionary(uniqueKeysWithValues: wordStats.sorted { $0.value > $1.value }.prefix(4000).map { ($0.key, $0.value) })
    }

    private func autosave() {
        recordsSinceSave += 1
        if recordsSinceSave >= 50 {
            recordsSinceSave = 0
            save()
        }
    }

    // MARK: - Persistence

    func save() {
        let payload: [String: Any] = ["lines": lineIndex, "words": wordStats]
        UserDefaults.standard.set(payload, forKey: "sp.suggestDB")
    }

    private func load() {
        guard let payload = UserDefaults.standard.dictionary(forKey: "sp.suggestDB") else { return }
        lineIndex = payload["lines"] as? [String: [String: Int]] ?? [:]
        wordStats = payload["words"] as? [String: Int] ?? [:]
    }
}
