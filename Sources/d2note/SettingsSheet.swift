import AppKit

final class SettingsSheet: NSWindow {

    var onChange: (() -> Void)?

    private let themePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let fontSizeLabel = NSTextField(labelWithString: "")
    private let fontStepper = NSStepper(frame: .zero)
    private let tabPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let wrapCheck = NSButton(checkboxWithTitle: "自动换行", target: nil, action: nil)
    private let gutterCheck = NSButton(checkboxWithTitle: "显示行号", target: nil, action: nil)
    private let pairsCheck = NSButton(checkboxWithTitle: "自动补全括号引号", target: nil, action: nil)
    private let suggestCheck = NSButton(checkboxWithTitle: "智能推荐（本机习惯学习，默认关闭）", target: nil, action: nil)
    private let draftCheck = NSButton(checkboxWithTitle: "自动保存草稿（未保存内容跨启动恢复）", target: nil, action: nil)

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 460, height: 268),
                   styleMask: [.titled], backing: .buffered, defer: false)
        title = "偏好设置"
        isReleasedWhenClosed = false

        let content = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 268))
        contentView = content

        themePopup.addItems(withTitles: ["Dark", "Light"])
        themePopup.selectItem(withTitle: Theme.current.name)
        themePopup.target = self
        themePopup.action = #selector(anyChanged)

        fontStepper.minValue = 9
        fontStepper.maxValue = 32
        fontStepper.increment = 1
        fontStepper.valueWraps = false
        fontStepper.target = self
        fontStepper.action = #selector(anyChanged)

        tabPopup.addItems(withTitles: ["2", "4", "8"])
        tabPopup.selectItem(withTitle: String(Prefs.tabWidth))
        tabPopup.target = self
        tabPopup.action = #selector(anyChanged)

        wrapCheck.target = self; wrapCheck.action = #selector(anyChanged)
        gutterCheck.target = self; gutterCheck.action = #selector(anyChanged)
        pairsCheck.target = self; pairsCheck.action = #selector(anyChanged)
        suggestCheck.target = self; suggestCheck.action = #selector(anyChanged)
        draftCheck.target = self; draftCheck.action = #selector(anyChanged)

        // Grid keeps the two columns perfectly aligned (HIG: aligned rows scan better)
        let grid = NSGridView(numberOfColumns: 2, rows: 0)
        grid.rowSpacing = 16
        grid.columnSpacing = 16
        grid.column(at: 0).xPlacement = .trailing

        func addRow(_ label: String, _ control: NSView) {
            let l = NSTextField(labelWithString: label)
            l.font = NSFont.systemFont(ofSize: 13)
            l.alignment = .right
            grid.addRow(with: [l, control])
        }

        let fontRow = NSView()
        fontRow.frame = NSRect(x: 0, y: 0, width: 220, height: 24)
        fontSizeLabel.font = NSFont.systemFont(ofSize: 13)
        fontSizeLabel.frame = NSRect(x: 0, y: 4, width: 44, height: 16)
        fontStepper.frame = NSRect(x: 50, y: 0, width: 19, height: 24)
        fontRow.addSubview(fontSizeLabel)
        fontRow.addSubview(fontStepper)

        addRow("主题", themePopup)
        addRow("字号", fontRow)
        addRow("缩进宽度", tabPopup)
        addRow("", gutterCheck)
        addRow("", wrapCheck)
        addRow("", pairsCheck)
        addRow("", suggestCheck)
        addRow("", draftCheck)

        grid.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(grid)

        let done = NSButton(title: "完成", target: self, action: #selector(doneTapped))
        done.bezelStyle = .rounded
        done.keyEquivalent = "\r"
        done.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(done)

        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            grid.centerXAnchor.constraint(equalTo: content.centerXAnchor, constant: -18),
            done.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            done.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -18),
        ])
        syncControls()
    }

    private func syncControls() {
        fontSizeLabel.stringValue = "\(Prefs.fontSize) pt"
        fontStepper.doubleValue = Double(Prefs.fontSize)
        wrapCheck.state = Prefs.wordWrap ? .on : .off
        gutterCheck.state = Prefs.lineNumbers ? .on : .off
        pairsCheck.state = Prefs.autoClosePairs ? .on : .off
        suggestCheck.state = Prefs.smartSuggest ? .on : .off
        draftCheck.state = Prefs.autoSaveDrafts ? .on : .off
    }

    @objc private func anyChanged() {
        if let name = themePopup.titleOfSelectedItem {
            Theme.current = name == "Light" ? .light : .dark
        }
        Prefs.fontSize = Int(fontStepper.doubleValue)
        if let tw = tabPopup.titleOfSelectedItem, let w = Int(tw) { Prefs.tabWidth = w }
        Prefs.wordWrap = wrapCheck.state == .on
        Prefs.lineNumbers = gutterCheck.state == .on
        Prefs.autoClosePairs = pairsCheck.state == .on
        Prefs.smartSuggest = suggestCheck.state == .on
        Prefs.autoSaveDrafts = draftCheck.state == .on
        fontSizeLabel.stringValue = "\(Prefs.fontSize) pt"
        onChange?()
    }

    @objc private func doneTapped() {
        sheetParent?.endSheet(self)
    }
}
