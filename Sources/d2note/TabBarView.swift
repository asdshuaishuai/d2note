import AppKit

protocol TabBarDelegate: AnyObject {
    func numberOfTabs() -> Int
    func tabTitle(_ index: Int) -> String
    func tabIsDirty(_ index: Int) -> Bool
    func tabLanguage(_ index: Int) -> SourceLanguage
    func tabToolTip(_ index: Int) -> String?
    func activeTabIndex() -> Int
    func tabBarDidSelect(_ index: Int)
    func tabBarDidClose(_ index: Int)
    func tabBarDidClickPlus()
    func tabBarDidReorder(from: Int, to: Int)
}

final class TabBarView: NSView {

    weak var delegate: TabBarDelegate?
    var theme: Theme = .current { didSet { needsDisplay = true } }

    private var hoverTabIndex: Int? = nil
    private var hoverPlus = false
    private var pressLocation: NSPoint? = nil
    private var pressIndex: Int? = nil
    private var dragOriginX: CGFloat? = nil
    private var tabOffset: CGFloat = 0  // scroll offset when tabs overflow

    private static let barHeight: CGFloat = 36
    private static let plusWidth: CGFloat = 40
    private static let minTabWidth: CGFloat = 120
    private static let maxTabWidth: CGFloat = 230
    private static let closeSize: CGFloat = 18

    override var isFlipped: Bool { true }

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 800, height: TabBarView.barHeight))
        let tracking = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self
        )
        addTrackingArea(tracking)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    var preferredHeight: CGFloat { TabBarView.barHeight }

    // MARK: - Geometry

    private func tabLayout(count: Int) -> (rects: [NSRect], areaWidth: CGFloat, maxOffset: CGFloat) {
        var rects: [NSRect] = []
        let areaWidth = bounds.width - TabBarView.plusWidth
        guard count > 0 else { return (rects, areaWidth, 0) }
        let natural = min(TabBarView.maxTabWidth, areaWidth / CGFloat(count))
        let w = max(TabBarView.minTabWidth, natural)
        let contentWidth = w * CGFloat(count)
        let maxOffset = max(0, contentWidth - areaWidth)
        let off = min(max(0, tabOffset), maxOffset)
        var x = -off
        for _ in 0..<count {
            rects.append(NSRect(x: x, y: 0, width: w, height: TabBarView.barHeight))
            x += w
        }
        return (rects, areaWidth, maxOffset)
    }

    /// Keep the active tab visible when tabs overflow.
    func scrollToActive() {
        let count = delegate?.numberOfTabs() ?? 0
        guard count > 0, let active = delegate?.activeTabIndex() else { return }
        let (rects, areaWidth, maxOffset) = tabLayout(count: count)
        guard maxOffset > 0, rects.indices.contains(active) else { return }
        let r = rects[active]
        var off = tabOffset
        if r.minX < 0 { off += r.minX }
        if r.maxX > areaWidth { off += r.maxX - areaWidth }
        let clamped = min(max(0, off), maxOffset)
        if abs(clamped - tabOffset) > 0.5 {
            tabOffset = clamped
            needsDisplay = true
        }
    }

    private func scrollBy(_ delta: CGFloat) {
        let (_, areaWidth, maxOffset) = tabLayout(count: delegate?.numberOfTabs() ?? 0)
        guard maxOffset > 0 else { return }
        tabOffset = min(max(0, tabOffset + delta), maxOffset)
        needsDisplay = true
    }

    override func scrollWheel(with event: NSEvent) {
        let (_, areaWidth, maxOffset) = tabLayout(count: delegate?.numberOfTabs() ?? 0)
        guard maxOffset > 0 else { super.scrollWheel(with: event); return }
        let delta = abs(event.scrollingDeltaX) >= abs(event.scrollingDeltaY)
            ? event.scrollingDeltaX : event.scrollingDeltaY
        guard delta != 0 else { return }
        scrollBy(delta * 2)
    }

    /// Chevron buttons shown when tabs overflow: (rect, direction).
    private func chevronRects(areaWidth: CGFloat) -> [(NSRect, CGFloat)] {
        let h = TabBarView.barHeight
        let r1 = NSRect(x: areaWidth - 68, y: (h - 22) / 2, width: 30, height: 22)
        let r2 = NSRect(x: areaWidth - 34, y: (h - 22) / 2, width: 30, height: 22)
        return [(r1, -180), (r2, 180)]
    }

    private func closeRect(in tab: NSRect) -> NSRect {
        NSRect(x: tab.maxX - TabBarView.closeSize - 8, y: (TabBarView.barHeight - TabBarView.closeSize) / 2,
               width: TabBarView.closeSize, height: TabBarView.closeSize)
    }

    private func plusRect() -> NSRect {
        NSRect(x: bounds.width - TabBarView.plusWidth, y: 0, width: TabBarView.plusWidth, height: TabBarView.barHeight)
    }

    private func tabIndex(at point: NSPoint) -> Int? {
        let count = delegate?.numberOfTabs() ?? 0
        let (rects, areaWidth, _) = tabLayout(count: count)
        guard point.x <= areaWidth else { return nil }
        for (i, r) in rects.enumerated() where r.contains(point) {
            return i
        }
        return nil
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        theme.tabBarBackground.setFill()
        bounds.fill()

        let count = delegate?.numberOfTabs() ?? 0
        let (rects, areaWidth, maxOffset) = tabLayout(count: count)

        // clip drawing to the tab area (keep the + button zone clean)
        if let ctx = NSGraphicsContext.current {
            ctx.saveGraphicsState()
            NSBezierPath(rect: NSRect(x: 0, y: 0, width: areaWidth, height: TabBarView.barHeight)).setClip()
        }
        defer { NSGraphicsContext.current?.restoreGraphicsState() }

        guard count > 0 else { drawPlus(); return }
        let active = delegate?.activeTabIndex() ?? -1

        for (i, rect) in rects.enumerated() {
            let isActive = i == active
            let isHover = i == hoverTabIndex

            if isActive {
                // rounded-top tab: union of a body rect and two corner circles
                let body = NSRect(x: rect.minX + 2, y: 8, width: rect.width - 4, height: rect.height - 6)
                theme.editorBackground.setFill()
                NSBezierPath(rect: body).fill()
                for cx in [rect.minX + 10, rect.maxX - 10] {
                    NSBezierPath(ovalIn: NSRect(x: cx - 8, y: 0, width: 16, height: 16)).fill()
                }
                let accent = NSRect(x: rect.minX + 2, y: 0, width: rect.width - 4, height: 2)
                theme.accent.setFill()
                accent.fill()
            } else if isHover {
                let path = NSBezierPath(roundedRect: NSRect(x: rect.minX + 2, y: 2, width: rect.width - 4, height: rect.height - 6),
                                        xRadius: 8, yRadius: 8)
                theme.tabHoverBackground.setFill()
                path.fill()
            }

            // Separator between inactive neighbors
            if !isActive && i + 1 < count && i + 1 != active {
                theme.tabSeparator.setFill()
                NSRect(x: rect.maxX - 0.5, y: 8, width: 1, height: rect.height - 16).fill()
            }

            let title = delegate?.tabTitle(i) ?? ""
            let isDirty = delegate?.tabIsDirty(i) ?? false
            let showClose = isHover || isActive

            // File-type badge (16pt rounded square + language abbreviation)
            let lang = delegate?.tabLanguage(i) ?? .plain
            let badgeRect = NSRect(x: rect.minX + BarMetrics.inset,
                                   y: (TabBarView.barHeight - 16) / 2, width: 16, height: 16)
            let badge = NSBezierPath(roundedRect: badgeRect, xRadius: 4.5, yRadius: 4.5)
            lang.badgeColor.setFill()
            badge.fill()
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 6.5, weight: .bold),
                .foregroundColor: lang.badgeTextColor,
            ]
            let labelStr = lang.badgeLabel as NSString
            let labelSize = labelStr.size(withAttributes: labelAttrs)
            labelStr.draw(at: NSPoint(x: badgeRect.midX - labelSize.width / 2,
                                      y: badgeRect.midY - labelSize.height / 2 + 0.5),
                          withAttributes: labelAttrs)

            // Title — vertically centered on the same midline as the ✕ control
            let titleFont = NSFont.systemFont(ofSize: 12, weight: isActive ? .semibold : .regular)
            let para = NSMutableParagraphStyle()
            para.lineBreakMode = .byTruncatingMiddle
            let attrs: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: isActive ? theme.tabActiveText : theme.tabText,
                .paragraphStyle: para,
            ]
            let lineH = ceil(title.size(withAttributes: attrs).height)
            let titleX = badgeRect.maxX + 6
            let rightReserve = (showClose ? TabBarView.closeSize + 14 : BarMetrics.inset)
            let textRect = NSRect(x: titleX,
                                  y: (TabBarView.barHeight - lineH) / 2,
                                  width: max(24, rect.maxX - rightReserve - titleX),
                                  height: lineH + 2)
            (title as NSString).draw(in: textRect, withAttributes: attrs)

            // Close / dirty dot
            let crect = closeRect(in: rect)
            if isDirty && !showClose {
                let dot = NSRect(x: crect.midX - 2.5, y: crect.midY - 2.5, width: 5, height: 5)
                let dotPath = NSBezierPath(ovalIn: dot)
                theme.accent.setFill()
                dotPath.fill()
            }
            if showClose {
                if isHover {
                    let bg = NSBezierPath(ovalIn: crect.insetBy(dx: 1, dy: 1))
                    theme.tabHoverBackground.setFill()
                    bg.fill()
                }
                let cross = "✕"
                let crossAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 9, weight: .medium),
                    .foregroundColor: theme.tabActiveText.withAlphaComponent(0.8),
                ]
                let cs = (cross as NSString).size(withAttributes: crossAttrs)
                (cross as NSString).draw(at: NSPoint(x: crect.midX - cs.width / 2, y: crect.midY - cs.height / 2 + 0.5),
                                         withAttributes: crossAttrs)
            }
        }
        NSGraphicsContext.current?.restoreGraphicsState()

        // overflow chevrons
        if maxOffset > 0 {
            for (r, dir) in chevronRects(areaWidth: areaWidth) {
                let canGo = dir < 0 ? tabOffset > 0 : tabOffset < maxOffset
                let bg = NSBezierPath(roundedRect: r, xRadius: 6, yRadius: 6)
                (canGo ? theme.tabHoverBackground : theme.tabBarBackground).setFill()
                bg.fill()
                let chev = dir < 0 ? "‹" : "›"
                let cAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 15, weight: .medium),
                    .foregroundColor: canGo ? theme.tabActiveText : theme.tabText.withAlphaComponent(0.35),
                ]
                let cs = (chev as NSString).size(withAttributes: cAttrs)
                (chev as NSString).draw(at: NSPoint(x: r.midX - cs.width / 2, y: r.midY - cs.height / 2),
                                        withAttributes: cAttrs)
            }
        }

        drawPlus()
    }

    private func drawPlus() {
        let prect = plusRect()
        if hoverPlus {
            theme.tabHoverBackground.setFill()
            prect.fill()
        }
        let plus = "+"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .regular),
            .foregroundColor: hoverPlus ? theme.tabActiveText : theme.tabText,
        ]
        let size = (plus as NSString).size(withAttributes: attrs)
        (plus as NSString).draw(at: NSPoint(x: prect.midX - size.width / 2, y: prect.midY - size.height / 2),
                                withAttributes: attrs)
    }

    // MARK: - Mouse

    override func mouseMoved(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        hoverTabIndex = tabIndex(at: p)
        hoverPlus = plusRect().contains(p)
        if let idx = hoverTabIndex {
            toolTip = delegate?.tabToolTip(idx) ?? delegate?.tabTitle(idx)
        } else {
            toolTip = nil
        }
        needsDisplay = true
    }

    override func mouseEntered(with event: NSEvent) { mouseMoved(with: event) }

    override func mouseExited(with event: NSEvent) {
        hoverTabIndex = nil
        hoverPlus = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        pressLocation = p
        pressIndex = tabIndex(at: p)
        dragOriginX = p.x
        if event.clickCount == 2, tabIndex(at: p) == nil, !plusRect().contains(p) {
            delegate?.tabBarDidClickPlus()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let originX = dragOriginX, let from = pressIndex else { return }
        let p = convert(event.locationInWindow, from: nil)
        let count = delegate?.numberOfTabs() ?? 0
        let (rects, _, _) = tabLayout(count: count)
        guard from < rects.count else { return }
        let offset = p.x - originX
        if offset > rects[from].width / 2, from + 1 < count {
            delegate?.tabBarDidReorder(from: from, to: from + 1)
            pressIndex = from + 1
            dragOriginX = p.x
        } else if offset < -rects[from].width / 2, from - 1 >= 0 {
            delegate?.tabBarDidReorder(from: from, to: from - 1)
            pressIndex = from - 1
            dragOriginX = p.x
        }
    }

    override func mouseUp(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if let start = pressLocation {
            let moved = abs(p.x - start.x) + abs(p.y - start.y)
            if moved < 4 {
                if plusRect().contains(p) {
                    delegate?.tabBarDidClickPlus()
                    return
                }
                let (_, areaWidth, maxOffset) = tabLayout(count: delegate?.numberOfTabs() ?? 0)
                if maxOffset > 0 {
                    for (r, dir) in chevronRects(areaWidth: areaWidth) where r.contains(p) {
                        scrollBy(CGFloat(dir))
                        return
                    }
                }
                if let idx = tabIndex(at: p) {
                    let (rects, _, _) = tabLayout(count: delegate?.numberOfTabs() ?? 0)
                    if closeRect(in: rects[idx]).contains(p) {
                        delegate?.tabBarDidClose(idx)
                    } else {
                        delegate?.tabBarDidSelect(idx)
                    }
                }
            }
        }
        pressLocation = nil
        pressIndex = nil
        dragOriginX = nil
    }

    // MARK: - Drag & drop files

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self]) { return .copy }
        return []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              !urls.isEmpty else { return false }
        NotificationCenter.default.post(name: .swiftPadOpenURLs, object: urls)
        return true
    }
}

extension Notification.Name {
    static let swiftPadOpenURLs = Notification.Name("SwiftPadOpenURLs")
}
