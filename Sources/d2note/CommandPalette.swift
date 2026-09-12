import AppKit

struct CommandItem {
    let title: String
    let key: String
    let handler: () -> Void
}

/// VSCode-style command palette, rendered with pure frame layout.
final class CommandPaletteView: NSView, NSTextFieldDelegate {

    static let rowHeight: CGFloat = 30
    static let fieldAreaTop: CGFloat = 62
    private static let maxVisibleRows = 8

    var field: NSTextField!
    private var separator: NSView!
    private var rowViews: [NSView] = []

    var commands: [CommandItem] = [] {
        didSet { refilter() }
    }
    private var filtered: [CommandItem] = []
    private var selectedIndex = 0
    var onClose: (() -> Void)?
    var onRun: ((CommandItem) -> Void)?
    var onHeightChanged: ((CGFloat) -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)

        let effect = NSVisualEffectView(frame: bounds)
        effect.material = .popover
        effect.blendingMode = .withinWindow
        effect.state = .active
        effect.autoresizingMask = [.width, .height]
        addSubview(effect)

        field = NSTextField(frame: NSRect(x: 14, y: bounds.height - 36, width: bounds.width - 28, height: 24))
        field.font = NSFont.systemFont(ofSize: 14)
        field.placeholderString = "输入命令…（↑↓ 选择，回车执行，Esc 关闭）"
        field.focusRingType = .none
        field.isBordered = false
        field.drawsBackground = false
        field.delegate = self
        field.autoresizingMask = [.width]
        addSubview(field)

        separator = NSView(frame: NSRect(x: 0, y: bounds.height - 46, width: bounds.width, height: 1))
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor
        separator.autoresizingMask = [.width]
        addSubview(separator)

        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.masksToBounds = true
        shadow = NSShadow()
    }

    required init?(coder: NSCoder) { fatalError() }

    func desiredHeight(for width: CGFloat) -> CGFloat {
        CommandPaletteView.fieldAreaTop
            + min(CGFloat(max(filtered.count, 1)), CGFloat(8)) * CommandPaletteView.rowHeight + 12
    }

    // MARK: - Rows

    private func makeRow(_ cmd: CommandItem, index: Int, width: CGFloat) -> NSView {
        let row = NSView(frame: NSRect(x: 0, y: 0, width: width, height: CommandPaletteView.rowHeight))
        row.wantsLayer = true

        let title = NSTextField(labelWithString: cmd.title)
        title.font = NSFont.systemFont(ofSize: 13)
        title.lineBreakMode = .byTruncatingTail
        title.frame = NSRect(x: 14, y: 7, width: width - 180, height: 17)
        title.autoresizingMask = [.width]
        row.addSubview(title)

        let key = NSTextField(labelWithString: cmd.key)
        key.font = NSFont.systemFont(ofSize: 11)
        key.textColor = .secondaryLabelColor
        key.alignment = .right
        key.frame = NSRect(x: width - 134, y: 7, width: 120, height: 17)
        key.autoresizingMask = [.minXMargin]
        row.addSubview(key)

        let click = NSClickGestureRecognizer(target: self, action: #selector(rowClicked(_:)))
        row.addGestureRecognizer(click)
        return row
    }

    private func highlightRows() {
        for (i, row) in rowViews.enumerated() {
            row.layer?.backgroundColor = (i == selectedIndex)
                ? NSColor.selectedContentBackgroundColor.withAlphaComponent(0.35).cgColor
                : NSColor.clear.cgColor
        }
    }

    // MARK: - Filtering

    func resetAndFocus() {
        field.stringValue = ""
        refilter()
        window?.makeFirstResponder(field)
    }

    private func refilter() {
        let q = field.stringValue.trimmingCharacters(in: .whitespaces).lowercased()
        filtered = q.isEmpty ? commands : commands.filter { $0.title.lowercased().contains(q) }
        selectedIndex = filtered.isEmpty ? -1 : 0

        rowViews.forEach { $0.removeFromSuperview() }
        rowViews = []
        let width = max(320, bounds.width)
        var y = bounds.height - CommandPaletteView.fieldAreaTop
        for (i, cmd) in filtered.prefix(8).enumerated() {
            let row = makeRow(cmd, index: i, width: width)
            row.frame.origin.y = y - CommandPaletteView.rowHeight
            addSubview(row)
            rowViews.append(row)
            y -= CommandPaletteView.rowHeight
        }
        highlightRows()
    }

    private func moveSelection(_ delta: Int) {
        guard !filtered.isEmpty else { return }
        selectedIndex = min(max(0, selectedIndex + delta), filtered.count - 1)
        highlightRows()
    }

    private func runSelected() {
        guard filtered.indices.contains(selectedIndex) else { return }
        onRun?(filtered[selectedIndex])
    }

    @objc private func rowClicked(_ gr: NSClickGestureRecognizer) {
        guard let row = gr.view, let idx = rowViews.firstIndex(of: row) else { return }
        selectedIndex = idx
        highlightRows()
        runSelected()
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        refilter()
        onHeightChanged?(desiredHeight(for: bounds.width))
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(moveUp(_:)): moveSelection(-1); return true
        case #selector(moveDown(_:)): moveSelection(1); return true
        case #selector(insertNewline(_:)): runSelected(); return true
        case #selector(cancelOperation(_:)): onClose?(); return true
        default: return false
        }
    }
}

// MARK: - Floating panel host

/// Floating command palette panel shown centered over the main window.
final class CommandPalettePanel: NSPanel {

    let paletteView: CommandPaletteView
    var onClosed: (() -> Void)?

    init(commands: [CommandItem], onClose: @escaping () -> Void, onRun: @escaping (CommandItem) -> Void) {
        paletteView = CommandPaletteView(frame: NSRect(x: 0, y: 0, width: 520, height: 340))
        paletteView.commands = commands
        paletteView.onClose = onClose
        paletteView.onRun = onRun

        super.init(contentRect: NSRect(x: 0, y: 0, width: 520, height: 340),
                   styleMask: [.titled, .closable],
                   backing: .buffered, defer: false)
        title = "命令面板"
        level = .floating
        isReleasedWhenClosed = false
        contentView = paletteView

        paletteView.onClose = { [weak self] in
            self?.orderOut(nil)
            self?.onClosed?()
        }
        paletteView.onRun = { [weak self] cmd in
            self?.orderOut(nil)
            self?.onClosed?()
            cmd.handler()
        }
    }

    func present(relativeTo parent: NSWindow) {
        let pf = parent.frame
        setFrame(NSRect(x: pf.origin.x + (pf.width - 520) / 2,
                        y: pf.midY - 170,
                        width: 520, height: 340), display: false)
        parent.addChildWindow(self, ordered: .above)
        makeKeyAndOrderFront(nil)
        paletteView.resetAndFocus()
    }

    func paletteSize() -> Int { paletteView.filteredCount }
}

extension CommandPaletteView {
    var filteredCount: Int {
        let q = field.stringValue.trimmingCharacters(in: .whitespaces).lowercased()
        return q.isEmpty ? commands.count : commands.filter { $0.title.lowercased().contains(q) }.count
    }
}
