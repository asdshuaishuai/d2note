import AppKit

final class EditorDocument: NSObject {

    let textView: EditorTextView
    let scrollView: NSScrollView
    let ruler: LineNumberRulerView

    var fileURL: URL?
    var untitledNumber: Int?
    var displayTitle: String?
    var language: SourceLanguage = .plain
    var languageLocked = false
    var isDirty = false { didSet { dirtyHandler?(isDirty) } }
    var dirtyHandler: ((Bool) -> Void)?
    var needsRetokenize = true
    var encoding: String.Encoding = .utf8
    var hadBOM = false
    var isLoadingContent = false
    /// Set when the user explicitly discards changes; excluded from session save.
    var excludedFromSession = false

    private var cachedLineStarts: [Int]? = nil

    init(textView: EditorTextView, scrollView: NSScrollView, ruler: LineNumberRulerView) {
        self.textView = textView
        self.scrollView = scrollView
        self.ruler = ruler
        super.init()
    }

    var displayName: String {
        if let url = fileURL { return url.lastPathComponent }
        if let t = displayTitle { return t }
        if let n = untitledNumber { return "未命名 \(n)" }
        return "未命名"
    }

    var title: String { displayName + (isDirty ? " •" : "") }

    func invalidateLineCache() {
        cachedLineStarts = nil
    }

    func lineStartOffsets() -> [Int] {
        if let c = cachedLineStarts { return c }
        let s = textView.string as NSString
        var starts: [Int] = [0]
        var i = 0
        let len = s.length
        let swiftString = textView.string
        for ch in swiftString.utf16 {
            if ch == 0x0A { starts.append(i + 1) }
            i += 1
        }
        _ = len
        cachedLineStarts = starts
        return starts
    }

    var lineCount: Int { lineStartOffsets().count }

    func lineAndColumn(at location: Int) -> (line: Int, col: Int) {
        let starts = lineStartOffsets()
        let loc = min(max(0, location), (textView.string as NSString).length)
        var line = 0
        var lo = 0, hi = starts.count - 1
        while lo <= hi {
            let mid = (lo + hi) / 2
            if starts[mid] <= loc { line = mid; lo = mid + 1 } else { hi = mid - 1 }
        }
        let col = loc - starts[line] + 1
        return (line + 1, col)
    }

    func rangeOfLine(_ n: Int) -> NSRange {
        let s = textView.string as NSString
        let starts = lineStartOffsets()
        let idx = min(max(0, n - 1), starts.count - 1)
        let start = starts[idx]
        var end = s.length
        if idx + 1 < starts.count { end = starts[idx + 1] - 1 }
        return NSRange(location: start, length: max(0, min(end, s.length) - start))
    }

    func wordCount() -> Int {
        let text = textView.string
        guard !text.isEmpty else { return 0 }
        return text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
}
