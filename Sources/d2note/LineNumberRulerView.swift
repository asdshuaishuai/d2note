import AppKit

final class LineNumberRulerView: NSRulerView {

    weak var editor: EditorTextView?
    var lineStartsProvider: (() -> [Int])?
    var currentLineProvider: (() -> Int)?

    private var theme: Theme = .current
    private var font: NSFont = .monospacedDigitSystemFont(ofSize: 10.5, weight: .regular)

    init(scrollView: NSScrollView, editor: EditorTextView) {
        self.editor = editor
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = editor
        ruleThickness = 44
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
    }

    func applyTheme(_ theme: Theme) {
        self.theme = theme
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let editor, let lm = editor.layoutManager, let container = editor.textContainer else { return }
        let s = editor.string as NSString

        // Use bounds, not dirtyRect — the OS can hand us an oversized dirty rect.
        theme.gutterBackground.setFill()
        bounds.fill()
        let edge = NSBezierPath(rect: NSRect(x: bounds.maxX - 1, y: 0, width: 1, height: bounds.height))
        theme.tabSeparator.setFill()
        edge.fill()

        guard s.length > 0 else { return }

        let starts = lineStartsProvider?() ?? []
        guard !starts.isEmpty else { return }

        let visible = editor.enclosingScrollView?.contentView.bounds ?? editor.visibleRect
        let glyphRange = lm.glyphRange(forBoundingRect: visible, in: container)
        let currentLine = currentLineProvider?() ?? -1

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: theme.gutterText,
        ]
        let activeAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .semibold),
            .foregroundColor: theme.gutterActiveText,
        ]

        let rightPad: CGFloat = 10
        let numWidth = self.ruleThickness - rightPad - 6

        lm.enumerateLineFragments(forGlyphRange: glyphRange, using: { (fragRect: NSRect, _ usedRect: NSRect, _ tc: NSTextContainer, fragGlyphRange: NSRange, _ stop: UnsafeMutablePointer<ObjCBool>) in
            let location = fragGlyphRange.location
            let lineIdx = Self.lineNumber(for: location, starts: starts)
            guard lineIdx >= 0 else { return }
            let isActive = lineIdx == currentLine
            let str = "\(lineIdx + 1)" as NSString
            let size = str.size(withAttributes: isActive ? activeAttrs : attrs)
            let y = fragRect.minY + (fragRect.height - size.height) / 2 + 0.5
            let x = max(2, numWidth - size.width) + 6
            str.draw(at: NSPoint(x: x, y: y), withAttributes: isActive ? activeAttrs : attrs)
        })
    }

    static func lineNumber(for location: Int, starts: [Int]) -> Int {
        var lo = 0
        var hi = starts.count - 1
        var ans = -1
        while lo <= hi {
            let mid = (lo + hi) / 2
            if starts[mid] <= location {
                ans = mid
                lo = mid + 1
            } else {
                hi = mid - 1
            }
        }
        return ans
    }

    func updateThickness() {
        guard editor != nil else { return }
        let starts = lineStartsProvider?() ?? []
        let digits = max(2, String(starts.count).count)
        let charW = "0".size(withAttributes: [.font: font]).width
        let desired = CGFloat(digits) * charW + 22
        if abs(desired - ruleThickness) > 0.5 {
            ruleThickness = desired
        }
    }
}
