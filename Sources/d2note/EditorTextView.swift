import AppKit

final class EditorTextView: NSTextView, NSLayoutManagerDelegate {

    var onTextChanged: (() -> Void)?
    var onEscape: (() -> Void)?
    var onLineCommitted: ((String) -> Void)?

    /// Ghost-text suggestion (drawn after the caret; Tab accepts).
    var ghostText: String?
    private var lastGhostDrawRect: NSRect? = nil

    var language: SourceLanguage = .plain
    var indentUnit = "    "
    var autoClosePairs = true
    var fileDropHandler: (([URL]) -> Void)?

    private static let openToClose: [unichar: unichar] = [
        0x28: 0x29, // ( )
        0x5B: 0x5D, // [ ]
        0x7B: 0x7D, // { }
    ]
    private static let closeToOpen: [unichar: unichar] = [
        0x29: 0x28, 0x5D: 0x5B, 0x7D: 0x7B,
    ]
    private static let quotes: Set<unichar> = [0x22, 0x27, 0x60] // " ' `

    // Overlay bookkeeping (temporary attributes, never stored in text)
    private var bracketRanges: [NSRange] = []
    private var currentLineRange: NSRange? = nil

    convenience init() {
        let storage = NSTextStorage()
        let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        let manager = NSLayoutManager()
        manager.addTextContainer(container)
        storage.addLayoutManager(manager)
        self.init(frame: NSRect(x: 0, y: 0, width: 600, height: 400), textContainer: container)
        commonSetup()
    }

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        commonSetup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonSetup()
    }

    private func commonSetup() {
        allowsUndo = true
        isRichText = false
        importsGraphics = false
        usesFontPanel = false
        usesFindBar = false
        isIncrementalSearchingEnabled = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isContinuousSpellCheckingEnabled = false
        isGrammarCheckingEnabled = false
        isAutomaticLinkDetectionEnabled = false
        isAutomaticDataDetectionEnabled = false
        isAutomaticTextCompletionEnabled = false
        smartInsertDeleteEnabled = false
        allowsDocumentBackgroundColorChange = true
        layoutManager?.allowsNonContiguousLayout = false
        layoutManager?.delegate = self
        isVerticallyResizable = true
        isHorizontallyResizable = true
        textContainerInset = NSSize(width: 6, height: 8)
        minSize = NSSize.zero
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        // 容器不追踪 textView —— 布局完成后由 updateFrameToContent 把
        // textView frame 同步到内容尺寸。heightTracksTextView=true 会把
        // 滚动范围锁死在初始高度（超长内容滚不下去）。
        textContainer?.heightTracksTextView = false
        textContainer?.size = NSSize(width: 0, height: 0)
        registerForDraggedTypes([.fileURL])
    }

    // MARK: - Content-driven frame growth

    /// 把 textView 的高度（与关闭换行时的宽度）同步到排版内容尺寸。
    func updateFrameToContent() {
        guard let lm = layoutManager, let tc = textContainer, window != nil else { return }
        let used = lm.usedRect(for: tc)
        var size = NSSize(width: used.width + textContainerInset.width * 2,
                          height: used.height + textContainerInset.height * 2)
        if let clip = enclosingScrollView?.contentView {
            size.width = max(size.width, clip.bounds.width)
            size.height = max(size.height, clip.bounds.height)
        }
        if abs(frame.width - size.width) > 0.5 || abs(frame.height - size.height) > 0.5 {
            setFrameSize(size)
        }
    }

    // MARK: - Word wrap

    func setWordWrap(_ on: Bool) {
        textContainer?.widthTracksTextView = on
        if on {
            textContainer?.size = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        } else {
            textContainer?.size = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }
        enclosingScrollView?.hasHorizontalScroller = !on
        updateFrameToContent()
    }

    func applyTheme(_ theme: Theme, font: NSFont) {
        backgroundColor = theme.editorBackground
        drawsBackground = true
        insertionPointColor = theme.insertPoint
        textColor = theme.editorText
        selectedTextAttributes = [.backgroundColor: theme.selection]
        self.font = font
        needsDisplay = true
    }

    // MARK: - Word wrap

    static let noRange = NSRange(location: NSNotFound, length: 0)

    // MARK: - Text insertion with auto-pairs

    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        guard autoClosePairs,
              let str = insertString as? String,
              let first = str.utf16.first, str.utf16.count == 1,
              first < 0x80,
              replacementRange == EditorTextView.noRange,
              selectedRange().length == 0 else {
            super.insertText(insertString, replacementRange: replacementRange)
            return
        }

        let r = selectedRange()
        let s = string as NSString
        let next: unichar = r.location < s.length ? s.character(at: r.location) : 0
        let prev: unichar = r.location > 0 ? s.character(at: r.location - 1) : 0

        // Typing a closer that matches the next char: just step over it
        if EditorTextView.closeToOpen[first] != nil, next == first {
            setSelectedRange(NSRange(location: r.location + 1, length: 0))
            return
        }
        // Quotes: step over when next is the same quote
        if EditorTextView.quotes.contains(first), next == first {
            setSelectedRange(NSRange(location: r.location + 1, length: 0))
            return
        }

        let nextIsWord = isWordChar(next)
        let prevIsWord = isWordChar(prev)
        let prevNeutral = !prevIsWord

        // Bracket pair
        if let closer = EditorTextView.openToClose[first], !nextIsWord,
           let closerScalar = UnicodeScalar(closer) {
            super.insertText("\(str)\(Character(closerScalar))", replacementRange: EditorTextView.noRange)
            setSelectedRange(NSRange(location: r.location + 1, length: 0))
            return
        }
        // Quote pair: only when surrounded by neutral chars
        if EditorTextView.quotes.contains(first), prevNeutral, !nextIsWord {
            super.insertText("\(str)\(str)", replacementRange: EditorTextView.noRange)
            setSelectedRange(NSRange(location: r.location + 1, length: 0))
            return
        }
        super.insertText(insertString, replacementRange: replacementRange)
    }

    // MARK: - Commands (auto-indent, tab handling, smart delete)

    override func doCommand(by selector: Selector) {
        switch selector {
        case #selector(insertNewline(_:)):
            smartNewline()
        case #selector(insertTab(_:)):
            handleTab()
        case #selector(insertBacktab(_:)):
            shiftSelectedLines(-1)
        case #selector(deleteBackward(_:)):
            if !smartPairDelete() {
                super.doCommand(by: selector)
            }
        case #selector(cancelOperation(_:)):
            if ghostText != nil, Prefs.smartSuggest {
                updateGhostSuggestion()
            } else if let onEscape {
                onEscape()
            } else {
                super.doCommand(by: selector)
            }
        default:
            super.doCommand(by: selector)
        }
    }

    private func smartNewline() {
        let r = selectedRange()
        let s = string as NSString
        let lineRange = s.lineRange(for: NSRange(location: min(r.location, s.length), length: 0))
        let line = s.substring(with: lineRange)
        let indent = String(line.prefix { $0 == " " || $0 == "\t" })

        // habit learning: commit the line the user just finished typing
        if r.length == 0, r.location >= lineRange.location {
            let typedUpToCaret = s.substring(with: NSRange(location: lineRange.location, length: r.location - lineRange.location))
            let trimmed = typedUpToCaret.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                onLineCommitted?(trimmed)
            }
        }

        var insert = "\n" + indent
        var caretBack = 0

        let prev: unichar = r.location > 0 ? s.character(at: r.location - 1) : 0
        let next: unichar = r.location < s.length ? s.character(at: r.location) : 0

        if let closer = EditorTextView.openToClose[prev] {
            insert += indentUnit
            if next == closer {
                insert += "\n" + indent
                caretBack = indentUnit.utf16.count + 1
            }
        } else if language == .python,
                  line.trimmingCharacters(in: .whitespaces).hasSuffix(":") {
            insert += indentUnit
        }

        insertText(insert, replacementRange: EditorTextView.noRange)
        if caretBack > 0 {
            let loc = selectedRange().location - caretBack
            setSelectedRange(NSRange(location: loc, length: 0))
        }
    }

    private func handleTab() {
        // Tab accepts a ghost suggestion when one is showing at the caret
        if Prefs.smartSuggest, let ghost = ghostText, !ghost.isEmpty, selectedRange().length == 0 {
            insertText(ghost, replacementRange: EditorTextView.noRange)
            updateGhostSuggestion()
            return
        }
        let r = selectedRange()
        if r.length > 0 {
            shiftSelectedLines(+1)
        } else {
            insertText(indentUnit, replacementRange: EditorTextView.noRange)
        }
    }

    private func selectedLineRange() -> NSRange {
        let s = string as NSString
        let r = selectedRange()
        let startLine = s.lineRange(for: NSRange(location: min(r.location, s.length), length: 0))
        let endLocation = min(r.location + r.length, s.length)
        var endLine = s.lineRange(for: NSRange(location: max(startLine.location, endLocation - 1), length: 0))
        endLine.length = min(s.length - endLine.location, endLine.length)
        let loc = startLine.location
        let len = NSMaxRange(endLine) - loc
        return NSRange(location: loc, length: max(0, len))
    }

    private func shiftSelectedLines(_ direction: Int) {
        let s = string as NSString
        let range = selectedLineRange()
        guard range.length > 0 || direction < 0 else { return }
        let text = s.substring(with: range)
        let unitLen = indentUnit.utf16.count
        var lines = text.components(separatedBy: "\n")
        var delta = 0
        for (idx, line) in lines.enumerated() {
            if direction > 0 {
                if !line.isEmpty || lines.count == 1 {
                    lines[idx] = indentUnit + line
                    if idx == 0 { delta = unitLen }
                }
            } else {
                var l = Substring(line)
                var removed = 0
                if l.hasPrefix(indentUnit) {
                    l = l.dropFirst(unitLen)
                    removed = unitLen
                } else {
                    while let f = l.first, f == " " || f == "\t", removed < unitLen {
                        l = l.dropFirst()
                        removed += 1
                    }
                }
                if idx == 0 { delta = -removed }
                lines[idx] = String(l)
            }
        }
        let newText = lines.joined(separator: "\n")
        insertText(newText, replacementRange: range)
        let newLoc = max(0, min(s.length, range.location + delta))
        let newEnd = newLoc + max(0, range.length + delta)
        setSelectedRange(NSRange(location: newLoc, length: max(0, newEnd - newLoc)))
    }

    private func smartPairDelete() -> Bool {
        let r = selectedRange()
        guard r.length == 0, r.location > 0 else { return false }
        let s = string as NSString
        guard r.location < s.length else { return false }
        let a = s.character(at: r.location - 1)
        let b = s.character(at: r.location)
        if let closer = EditorTextView.openToClose[a], closer == b {
            deleteRangeSilently(NSRange(location: r.location - 1, length: 2))
            return true
        }
        if EditorTextView.quotes.contains(a), a == b {
            deleteRangeSilently(NSRange(location: r.location - 1, length: 2))
            return true
        }
        return false
    }

    private func deleteRangeSilently(_ range: NSRange) {
        if shouldChangeText(in: range, replacementString: "") {
            textStorage?.replaceCharacters(in: range, with: "")
            didChangeText()
        }
    }

    // MARK: - Bracket matching & current line overlays (temporary attributes)

    func updateOverlays(theme: Theme) {
        let lm = layoutManager
        let len = (string as NSString).length
        guard let lm else { return }
        if bracketRanges.count > 0 {
            for r in bracketRanges {
                lm.removeTemporaryAttribute(.backgroundColor, forCharacterRange: r)
            }
            bracketRanges = []
        }
        if let cl = currentLineRange {
            lm.removeTemporaryAttribute(.backgroundColor, forCharacterRange: cl)
            currentLineRange = nil
        }
        guard len > 0 else { return }

        let r = selectedRange()
        // current line highlight (only for empty selection)
        if r.length == 0, let doc = string as NSString? {
            let lineRange = doc.lineRange(for: NSRange(location: min(r.location, len), length: 0))
            let cl = NSRange(location: lineRange.location, length: min(lineRange.length, len - lineRange.location))
            if cl.length > 0 {
                lm.addTemporaryAttribute(.backgroundColor, value: theme.currentLine, forCharacterRange: cl)
                currentLineRange = cl
            }
        }
        // bracket match
        if r.length == 0, let pair = locateBracketPair() {
            for loc in pair {
                let rr = NSRange(location: loc, length: 1)
                lm.addTemporaryAttribute(.backgroundColor, value: theme.bracketHighlight, forCharacterRange: rr)
                bracketRanges.append(rr)
            }
        }
    }

    private func locateBracketPair() -> [Int]? {
        let s = string as NSString
        let len = s.length
        let r = selectedRange()
        guard len > 0 else { return nil }
        let before: unichar = r.location > 0 ? s.character(at: r.location - 1) : 0
        let after: unichar = r.location < len ? s.character(at: r.location) : 0

        if let closer = EditorTextView.openToClose[before] {
            if let m = findMatch(from: r.location - 1, open: before, close: closer, forward: true) {
                return [r.location - 1, m]
            }
        }
        if let opener = EditorTextView.closeToOpen[after] {
            if let m = findMatch(from: r.location, open: opener, close: after, forward: false) {
                return [m, r.location]
            }
        }
        if let closer = EditorTextView.openToClose[before], let opener = EditorTextView.closeToOpen[before],
           before == after, false {
            _ = closer; _ = opener
        }
        return nil
    }

    private func findMatch(from start: Int, open: unichar, close: unichar, forward: Bool) -> Int? {
        let s = string as NSString
        let len = s.length
        var depth = 0
        let maxSteps = 500_000
        var steps = 0
        var i = start
        while i >= 0 && i < len && steps < maxSteps {
            let c = s.character(at: i)
            if c == open { depth += forward ? 1 : -1 }
            if c == close { depth += forward ? -1 : 1 }
            if depth == 0 { return i }
            i += forward ? 1 : -1
            steps += 1
        }
        return nil
    }

    // MARK: - Ghost suggestions (on-device habit learning)

    /// Recompute the ghost suggestion for the caret position.
    func updateGhostSuggestion() {
        if let r = lastGhostDrawRect { setNeedsDisplay(r) }
        lastGhostDrawRect = nil
        ghostText = nil

        guard Prefs.smartSuggest, selectedRange().length == 0 else {
            needsDisplay = true
            return
        }
        let s = string as NSString
        let n = s.length
        let loc = min(selectedRange().location, n)
        let lineStart = s.lineRange(for: NSRange(location: loc, length: 0)).location
        let typed = s.substring(with: NSRange(location: lineStart, length: loc - lineStart))
        let engine = SuggestionEngine.shared

        var suggestion: String?
        if let last = typed.utf16.last, isWordChar(last), typed.utf16.count >= 2 {
            // caret right after a word: word completion
            var wordStart = loc
            while wordStart > lineStart, isWordChar(s.character(at: wordStart - 1)) { wordStart -= 1 }
            let word = s.substring(with: NSRange(location: wordStart, length: loc - wordStart))
            suggestion = engine.wordSuggestion(for: word)
        }
        if suggestion == nil {
            suggestion = engine.lineSuggestion(for: typed)
        }

        ghostText = suggestion
        if suggestion != nil, let p = ghostPoint() {
            let height = (font?.boundingRectForFont.height ?? 16) + 6
            setNeedsDisplay(NSRect(x: p.x, y: p.y - 2, width: min(900, max(240, bounds.maxX - p.x)), height: height))
        } else {
            needsDisplay = true
        }
    }

    private func ghostPoint() -> NSPoint? {
        guard let lm = layoutManager, let tc = textContainer else { return nil }
        let n = (string as NSString).length
        let loc = selectedRange().location
        guard loc <= n, selectedRange().length == 0 else { return nil }
        let origin = textContainerOrigin
        guard lm.numberOfGlyphs > 0 else {
            return NSPoint(x: origin.x, y: origin.y)
        }
        // This SDK removed glyphIndex(forCharacterAt:), so locate the caret's
        // line fragment by enumeration and measure the typed prefix width.
        let glyphs = lm.glyphRange(forBoundingRect: bounds, in: tc)
        let fontAttrs: [NSAttributedString.Key: Any] = [.font: font ?? NSFont.systemFont(ofSize: 13)]
        let s = string as NSString
        var result: NSPoint? = nil
        lm.enumerateLineFragments(forGlyphRange: glyphs, using: { (fragRect: NSRect, usedRect: NSRect, _ cont: NSTextContainer, fragGlyphRange: NSRange, stop: UnsafeMutablePointer<ObjCBool>) in
            let charRange = lm.characterRange(forGlyphRange: fragGlyphRange, actualGlyphRange: nil)
            guard loc >= charRange.location, loc <= NSMaxRange(charRange) else { return }
            let typed = s.substring(with: NSRange(location: charRange.location, length: loc - charRange.location))
            let w = (typed as NSString).size(withAttributes: fontAttrs).width
            result = NSPoint(x: origin.x + usedRect.minX + w, y: origin.y + fragRect.minY)
            stop.pointee = true
        })
        if result == nil, let docRect = lastFragmentRect() {
            // caret at document end (past the last fragment's range)
            return NSPoint(x: origin.x + docRect.maxX, y: origin.y + docRect.minY)
        }
        return result
    }

    private func lastFragmentRect() -> NSRect? {
        guard let lm = layoutManager, let tc = textContainer, lm.numberOfGlyphs > 0 else { return nil }
        var rect: NSRect? = nil
        lm.enumerateLineFragments(forGlyphRange: lm.glyphRange(forBoundingRect: bounds, in: tc), using: { (_, usedRect: NSRect, _: NSTextContainer, _: NSRange, _: UnsafeMutablePointer<ObjCBool>) in
            rect = usedRect
        })
        return rect
    }

    private func drawGhost() {
        guard Prefs.smartSuggest, let ghost = ghostText, !ghost.isEmpty,
              selectedRange().length == 0, let p = ghostPoint() else { return }
        let baseFont = font ?? NSFont.systemFont(ofSize: 13)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask),
            .foregroundColor: Theme.current.editorText.withAlphaComponent(0.38),
        ]
        (ghost as NSString).draw(at: p, withAttributes: attrs)
        let height = baseFont.boundingRectForFont.height + 6
        lastGhostDrawRect = NSRect(x: p.x, y: p.y - 2, width: min(900, max(240, bounds.maxX - p.x)), height: height)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawGhost()
    }

    // MARK: - Context menu (中文右键菜单)

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()

        func item(_ title: String, _ action: Selector, key: String = "", mods: NSEvent.ModifierFlags = []) -> NSMenuItem {
            let mi = NSMenuItem(title: title, action: action, keyEquivalent: key)
            mi.keyEquivalentModifierMask = mods
            menu.addItem(mi)
            return mi
        }
        func separator() { menu.addItem(.separator()) }

        let hasSelection = selectedRange().length > 0

        item("剪切", Selector(("cut:")), key: "x")
        item("拷贝", Selector(("copy:")), key: "c")
        item("粘贴", Selector(("paste:")), key: "v")
        let deleteItem = item("删除", Selector(("delete:")))
        deleteItem.isEnabled = hasSelection || selectedRange().location < (string as NSString).length
        separator()
        item("全选", Selector(("selectAll:")), key: "a")
        separator()
        item("切换注释", #selector(AppDelegate.toggleComment(_:)), key: "/")
        if hasSelection {
            item("翻译所选", #selector(AppDelegate.translateAction(_:)), key: "t", mods: [.command, .option])
        } else {
            item("翻译全文", #selector(AppDelegate.translateAction(_:)), key: "t", mods: [.command, .option])
        }
        separator()
        item("格式化文档（智能缩进）", #selector(AppDelegate.formatDocument(_:)), key: "f", mods: [.command, .shift, .option])
        item("格式化 JSON", #selector(AppDelegate.formatJSONAction(_:)), key: "j", mods: [.command, .shift])
        separator()
        item("排序所选行", #selector(AppDelegate.sortLinesAction(_:)))
        item("行倒序", #selector(AppDelegate.reverseLinesAction(_:)))
        item("去除重复行", #selector(AppDelegate.dedupeLinesAction(_:)))
        item("删除空行", #selector(AppDelegate.removeEmptyLinesAction(_:)))
        separator()
        item("跳转到行…", #selector(AppDelegate.goToLine(_:)), key: "l")

        return menu
    }

    // MARK: - Events

    override func didChangeText() {
        super.didChangeText()
        updateFrameToContent()
        onTextChanged?()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           !urls.isEmpty, urls.allSatisfy({ $0.isFileURL }) {
            fileDropHandler?(urls)
            return true
        }
        return super.performDragOperation(sender)
    }

    private func isWordChar(_ c: unichar) -> Bool {
        let letter = (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c >= 0x80
        return letter || (c >= 48 && c <= 57) || c == 0x5F
    }
}
