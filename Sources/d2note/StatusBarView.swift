import AppKit

// Shared metrics so every bar lines up on the same grid (HIG: align
// components so they are easy to scan).
enum BarMetrics {
    static let inset: CGFloat = 12          // leading/trailing padding
    static let barHeight: CGFloat = 24      // status / find / goto bar height
    static let groupGap: CGFloat = 16       // gap between control groups
    static let itemGap: CGFloat = 8         // gap inside a group
    static let controlHeight: CGFloat = 20  // small controls
}

final class StatusBarView: NSView {

    let positionLabel = NSTextField(labelWithString: "Ln 1, Col 1")
    let statsLabel = NSTextField(labelWithString: "")
    let spacesLabel = NSTextField(labelWithString: "空格: 4")
    let encodingLabel = NSTextField(labelWithString: "UTF-8")
    let languagePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let translateButton = NSButton(title: "翻译", target: nil, action: nil)

    var onLanguageChanged: ((SourceLanguage) -> Void)?
    var onTranslate: (() -> Void)?
    var onPositionClick: (() -> Void)?

    var theme: Theme = .current { didSet { needsDisplay = true } }

    override init(frame: NSRect) {
        super.init(frame: frame)
        for label in [positionLabel, statsLabel, spacesLabel, encodingLabel] {
            label.font = NSFont.systemFont(ofSize: 11)
            addSubview(label)
        }
        languagePopup.font = NSFont.systemFont(ofSize: 11)
        languagePopup.isBordered = false
        for lang in SourceLanguage.allCases {
            languagePopup.addItem(withTitle: lang.displayName)
        }
        languagePopup.target = self
        languagePopup.action = #selector(languageSelected)
        addSubview(languagePopup)

        translateButton.bezelStyle = .recessed
        translateButton.controlSize = .small
        translateButton.font = NSFont.systemFont(ofSize: 10)
        translateButton.toolTip = "翻译全文 / 所选文本（本地引擎）"
        translateButton.target = self
        translateButton.action = #selector(translateTapped)
        addSubview(translateButton)

        // 点击 "Ln x, Col y" 打开跳转到行
        let posClick = NSClickGestureRecognizer(target: self, action: #selector(positionClicked))
        positionLabel.addGestureRecognizer(posClick)
        positionLabel.toolTip = "点击跳转到指定行"

        applyTheme()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func applyTheme() {
        for label in [positionLabel, statsLabel, spacesLabel, encodingLabel] {
            label.textColor = theme.statusText
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        // Use bounds — the OS may hand us an oversized dirtyRect.
        theme.statusBarBackground.setFill()
        bounds.fill()
        theme.tabSeparator.setFill()
        NSRect(x: 0, y: bounds.maxY - 1, width: bounds.width, height: 1).fill()
    }

    @objc private func languageSelected() {
        guard let title = languagePopup.titleOfSelectedItem,
              let lang = SourceLanguage.fromDisplayName(title) else { return }
        onLanguageChanged?(lang)
    }

    @objc private func translateTapped() { onTranslate?() }
    @objc private func positionClicked() { onPositionClick?() }

    func setLanguage(_ lang: SourceLanguage) {
        languagePopup.selectItem(withTitle: lang.displayName)
    }

    func update(position: String, stats: String, spaces: Int, encoding: String, language: SourceLanguage) {
        positionLabel.stringValue = position
        statsLabel.stringValue = stats
        spacesLabel.stringValue = "空格: \(spaces)"
        encodingLabel.stringValue = encoding
        setLanguage(language)
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let h = bounds.height
        let y = (h - 16) / 2

        var x: CGFloat = BarMetrics.inset
        positionLabel.frame = NSRect(x: x, y: y, width: 110, height: 16)
        x += 110 + BarMetrics.itemGap
        statsLabel.frame = NSRect(x: x, y: y, width: 240, height: 16)

        // right group: [Spaces] [Encoding] [Translate] [Language]
        spacesLabel.sizeToFit()
        encodingLabel.sizeToFit()
        let langW: CGFloat = 108
        let translateW: CGFloat = 44
        let encW = encodingLabel.frame.width
        let spW = spacesLabel.frame.width

        var right = bounds.width - BarMetrics.inset - langW
        languagePopup.frame = NSRect(x: right, y: (h - 20) / 2, width: langW, height: 20)
        right -= BarMetrics.itemGap + translateW
        translateButton.frame = NSRect(x: right, y: (h - 18) / 2, width: translateW, height: 18)
        right -= BarMetrics.itemGap + encW
        encodingLabel.frame = NSRect(x: right, y: y, width: encW, height: 16)
        right -= BarMetrics.groupGap + spW
        spacesLabel.frame = NSRect(x: right, y: y, width: spW, height: 16)
    }
}

final class GoToBarView: NSView, NSTextFieldDelegate {

    let field = NSTextField(string: "")
    let hintLabel = NSTextField(labelWithString: "跳转到行 (1 - N)，回车确认，Esc 关闭")
    let goButton = NSButton(title: "跳转", target: nil, action: nil)

    var onGo: ((Int) -> Void)?
    var onClose: (() -> Void)?
    var maxLine = 1

    override init(frame: NSRect) {
        super.init(frame: frame)
        field.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        field.focusRingType = .none
        field.delegate = self
        field.target = self
        field.action = #selector(goTapped)
        hintLabel.font = NSFont.systemFont(ofSize: 11)
        hintLabel.textColor = .secondaryLabelColor
        goButton.bezelStyle = .rounded
        goButton.controlSize = .small
        goButton.target = self
        goButton.action = #selector(goTapped)
        addSubview(field)
        addSubview(hintLabel)
        addSubview(goButton)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        let h = newSize.height
        let y = (h - 26) / 2
        field.frame = NSRect(x: BarMetrics.inset - 2, y: y, width: 90, height: 26)
        goButton.frame = NSRect(x: field.frame.maxX + BarMetrics.itemGap, y: (h - 24) / 2, width: 52, height: 24)
        hintLabel.frame = NSRect(x: goButton.frame.maxX + BarMetrics.groupGap, y: (h - 16) / 2, width: 280, height: 16)
    }

    func focus() {
        window?.makeFirstResponder(field)
        field.selectText(nil)
    }

    @objc private func goTapped() {
        let n = Int(field.stringValue.trimmingCharacters(in: .whitespaces)) ?? 0
        if n >= 1 && n <= maxLine {
            onGo?(n)
        } else {
            NSSound.beep()
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(cancelOperation(_:)) {
            onClose?()
            return true
        }
        return false
    }
}
