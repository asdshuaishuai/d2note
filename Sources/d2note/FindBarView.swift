import AppKit

final class FindBarView: NSView, NSTextFieldDelegate {

    let searchField = NSTextField(string: "")
    let replaceField = NSTextField(string: "")
    let countLabel = NSTextField(labelWithString: "")
    private let prevButton = NSButton(image: NSImage(systemSymbolName: "chevron.up", accessibilityDescription: "上一个")!, target: nil, action: nil)
    private let nextButton = NSButton(image: NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "下一个")!, target: nil, action: nil)
    private let doneButton = NSButton(image: NSImage(systemSymbolName: "xmark", accessibilityDescription: "关闭")!, target: nil, action: nil)
    private let caseButton = NSButton(title: "Aa", target: nil, action: nil)
    private let regexButton = NSButton(title: ".*", target: nil, action: nil)
    private let replaceButton = NSButton(title: "替换", target: nil, action: nil)
    private let replaceAllButton = NSButton(title: "全部替换", target: nil, action: nil)
    private let replaceLabel = NSTextField(labelWithString: "替换为:")

    var replaceVisible = false { didSet { relayout() } }

    var onFindNext: (() -> Void)?
    var onFindPrev: (() -> Void)?
    var onQueryChanged: (() -> Void)?
    var onClose: (() -> Void)?
    var onReplace: (() -> Void)?
    var onReplaceAll: (() -> Void)?
    var onOptionsChanged: (() -> Void)?

    var isCaseSensitive: Bool { caseButton.state == .on }
    var isRegex: Bool { regexButton.state == .on }
    var query: String { searchField.stringValue }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        let fieldFont = NSFont.systemFont(ofSize: 12)
        searchField.font = fieldFont
        searchField.placeholderString = "查找"
        searchField.focusRingType = .none
        searchField.delegate = self
        searchField.action = #selector(searchSubmitted)
        searchField.target = self

        replaceField.font = fieldFont
        replaceField.placeholderString = "替换内容"
        replaceField.focusRingType = .none
        replaceField.delegate = self
        countLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        countLabel.textColor = .secondaryLabelColor

        for b in [prevButton, nextButton, doneButton] {
            b.bezelStyle = .texturedRounded
            b.isBordered = true
            b.image?.isTemplate = true
        }
        for b in [caseButton, regexButton] {
            b.bezelStyle = .recessed
            b.setButtonType(.pushOnPushOff)
            b.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        }
        for b in [replaceButton, replaceAllButton] {
            b.bezelStyle = .rounded
            b.controlSize = .small
            b.font = NSFont.systemFont(ofSize: 11)
        }
        replaceLabel.font = NSFont.systemFont(ofSize: 11)

        prevButton.target = self; prevButton.action = #selector(prevTapped)
        nextButton.target = self; nextButton.action = #selector(nextTapped)
        doneButton.target = self; doneButton.action = #selector(doneTapped)
        caseButton.target = self; caseButton.action = #selector(optionToggled)
        regexButton.target = self; regexButton.action = #selector(optionToggled)
        replaceButton.target = self; replaceButton.action = #selector(replaceTapped)
        replaceAllButton.target = self; replaceAllButton.action = #selector(replaceAllTapped)

        addSubview(searchField)
        addSubview(countLabel)
        addSubview(prevButton)
        addSubview(nextButton)
        addSubview(caseButton)
        addSubview(regexButton)
        addSubview(doneButton)
        addSubview(replaceLabel)
        addSubview(replaceField)
        addSubview(replaceButton)
        addSubview(replaceAllButton)
        relayout()
    }

    required init?(coder: NSCoder) { fatalError() }

    var preferredHeight: CGFloat { replaceVisible ? 78 : 44 }

    private func relayout() {
        let h = bounds.height
        let topY = replaceVisible ? h - 40 : (h - 26) / 2
        searchField.frame = NSRect(x: BarMetrics.inset, y: topY, width: 260, height: 26)
        countLabel.frame = NSRect(x: 280, y: topY + 5, width: 80, height: 16)
        prevButton.frame = NSRect(x: 366, y: topY - 1, width: 28, height: 28)
        nextButton.frame = NSRect(x: 394, y: topY - 1, width: 28, height: 28)
        caseButton.frame = NSRect(x: 428, y: topY, width: 34, height: 26)
        regexButton.frame = NSRect(x: 462, y: topY, width: 36, height: 26)
        doneButton.frame = NSRect(x: bounds.width - BarMetrics.inset - 28, y: topY - 1, width: 28, height: 28)

        let rowY: CGFloat = 9
        replaceLabel.frame = NSRect(x: BarMetrics.inset, y: rowY, width: 46, height: 18)
        replaceField.frame = NSRect(x: 64, y: rowY, width: 260, height: 26)
        replaceButton.frame = NSRect(x: 330, y: rowY, width: 58, height: 26)
        replaceAllButton.frame = NSRect(x: 392, y: rowY, width: 74, height: 26)
        replaceLabel.isHidden = !replaceVisible
        replaceField.isHidden = !replaceVisible
        replaceButton.isHidden = !replaceVisible
        replaceAllButton.isHidden = !replaceVisible
        needsLayout = true
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        relayout()
    }

    func focusSearch() {
        window?.makeFirstResponder(searchField)
        searchField.selectText(nil)
    }

    func focusReplace() {
        replaceVisible = true
        relayout()
        window?.makeFirstResponder(replaceField)
    }

    // MARK: - Actions

    @objc private func searchSubmitted() { onFindNext?() }
    @objc private func nextTapped() { onFindNext?() }
    @objc private func prevTapped() { onFindPrev?() }
    @objc private func doneTapped() { onClose?() }
    @objc private func optionToggled() { onOptionsChanged?() }
    @objc private func replaceTapped() { onReplace?() }
    @objc private func replaceAllTapped() { onReplaceAll?() }

    func controlTextDidChange(_ obj: Notification) {
        if obj.object as? NSTextField === searchField { onQueryChanged?() }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(cancelOperation(_:)) {
            onClose?()
            return true
        }
        if commandSelector == #selector(moveDown(_:)) {
            window?.makeFirstResponder(replaceField)
            return true
        }
        if commandSelector == #selector(moveUp(_:)) {
            window?.makeFirstResponder(searchField)
            return true
        }
        return false
    }
}
