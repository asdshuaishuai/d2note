import AppKit
import NaturalLanguage
import SwiftUI
import Translation

// MARK: - On-device translation (macOS 26+ Translation framework)

struct TranslationOutcome {
    let sourceName: String
    let targetName: String
    let text: String
}

enum TranslateError: LocalizedError {
    case noText
    case unsupportedPair
    case sourceNotInstalled

    var errorDescription: String? {
        switch self {
        case .noText: return "没有可翻译的内容。"
        case .unsupportedPair: return "该语言组合暂不支持本地翻译。"
        case .sourceNotInstalled: return "源语言模型尚未安装，请在 系统设置 → 通用 → 语言与地区 / 翻译 中下载。"
        }
    }
}

@available(macOS 26.0, *)
final class TranslationController: ObservableObject {
    @Published var config = TranslationSession.Configuration()
    @Published var runID = 0
    var pendingText = ""
    private(set) var pendingSource: Locale.Language?
    private(set) var pendingTarget: Locale.Language?
    var onResult: ((Result<TranslationSession.Response, Error>) -> Void)?

    func setPending(text: String, source: Locale.Language, target: Locale.Language) {
        pendingText = text
        pendingSource = source
        pendingTarget = target
        config = TranslationSession.Configuration(source: source, target: target)
        runID &+= 1
    }

    @MainActor
    func perform(_ session: TranslationSession) async {
        guard !pendingText.isEmpty else { return }
        do {
            let response = try await session.translate(pendingText)
            onResult?(.success(response))
        } catch {
            // 模型缺失时请求系统下载（SwiftUI 上下文中允许），完成后自动重试
            do {
                if await session.canRequestDownloads {
                    try await session.prepareTranslation()
                    let response = try await session.translate(pendingText)
                    onResult?(.success(response))
                } else {
                    onResult?(.failure(error))
                }
            } catch {
                onResult?(.failure(error))
            }
        }
        pendingText = ""
    }
}

@available(macOS 26.0, *)
struct TranslationBridgeView: View {
    @ObservedObject var controller: TranslationController

    var body: some View {
        Color.clear.frame(width: 1, height: 1)
            .translationTask(controller.config) { session in
                await controller.perform(session)
            }
            .id(controller.runID)
    }
}

/// Hosts the 1x1 SwiftUI bridge inside the main window.
@available(macOS 26.0, *)
final class TranslationHost {
    let controller = TranslationController()
    private var hostingView: NSHostingView<TranslationBridgeView>?

    func install(in parent: NSView) {
        guard hostingView == nil else { return }
        let hv = NSHostingView(rootView: TranslationBridgeView(controller: controller))
        hv.frame = NSRect(x: -4, y: -4, width: 1, height: 1)
        parent.addSubview(hv)
        hostingView = hv
    }

    func translate(text: String, source: Locale.Language, target: Locale.Language,
                   onResult: @escaping (Result<TranslationSession.Response, Error>) -> Void) {
        controller.onResult = onResult
        controller.setPending(text: text, source: source, target: target)
    }

    static func detectSource(_ text: String) -> Locale.Language? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(String(text.prefix(3000)))
        guard let nl = recognizer.dominantLanguage else { return nil }
        return Locale.Language(identifier: nl.rawValue)
    }

    static func preferredTarget(for source: Locale.Language) -> Locale.Language? {
        let sourceCode = source.languageCode?.identifier
        for identifier in Locale.preferredLanguages {
            let lang = Locale.Language(identifier: identifier)
            if lang.languageCode?.identifier != sourceCode {
                return lang
            }
        }
        return Locale.Language(identifier: "en")
    }

    static func localized(name language: Locale.Language) -> String? {
        if let code = language.languageCode?.identifier {
            return Locale.current.localizedString(forLanguageCode: code)
        }
        return nil
    }
}

// MARK: - Result panel

final class TranslatePanelWindow: NSWindow {

    private let metaLabel = NSTextField(labelWithString: "")
    private let textView = NSTextView()
    private let copyButton = NSButton(title: "拷贝", target: nil, action: nil)
    private let replaceButton = NSButton(title: "替换原文", target: nil, action: nil)
    private let closeButton = NSButton(title: "关闭", target: nil, action: nil)

    var onReplace: (() -> Void)?
    private var onCopy: (() -> Void)?

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 480, height: 380),
                   styleMask: [.titled, .closable, .resizable],
                   backing: .buffered, defer: false)
        title = "翻译"
        isReleasedWhenClosed = false
        level = .floating

        let content = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 380))
        contentView = content

        metaLabel.font = NSFont.systemFont(ofSize: 11)
        metaLabel.textColor = .secondaryLabelColor

        textView.isEditable = false
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textContainerInset = NSSize(width: 10, height: 10)

        let scroll = NSScrollView()
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .bezelBorder

        for b in [copyButton, replaceButton, closeButton] {
            b.bezelStyle = .rounded
            b.controlSize = .regular
        }
        copyButton.keyEquivalent = "c"
        copyButton.keyEquivalentModifierMask = .command
        closeButton.keyEquivalent = "\r"

        content.addSubview(metaLabel)
        content.addSubview(scroll)
        content.addSubview(copyButton)
        content.addSubview(replaceButton)
        content.addSubview(closeButton)
        for v in [metaLabel, scroll, copyButton, replaceButton, closeButton] {
            v.translatesAutoresizingMaskIntoConstraints = false
        }
        NSLayoutConstraint.activate([
            metaLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            metaLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            metaLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),

            scroll.topAnchor.constraint(equalTo: metaLabel.bottomAnchor, constant: 10),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),

            copyButton.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 12),
            copyButton.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            copyButton.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -14),

            replaceButton.topAnchor.constraint(equalTo: copyButton.topAnchor),
            replaceButton.leadingAnchor.constraint(equalTo: copyButton.trailingAnchor, constant: 10),
            replaceButton.bottomAnchor.constraint(equalTo: copyButton.bottomAnchor),

            closeButton.topAnchor.constraint(equalTo: copyButton.topAnchor),
            closeButton.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            closeButton.bottomAnchor.constraint(equalTo: copyButton.bottomAnchor),
        ])

        copyButton.target = self
        copyButton.action = #selector(copyTapped)
        replaceButton.target = self
        replaceButton.action = #selector(replaceTapped)
        closeButton.target = self
        closeButton.action = #selector(closeTapped)
    }

    func show(outcome: TranslationOutcome, replaceTitle: String, replaceHandler: @escaping () -> Void) {
        metaLabel.stringValue = "\(outcome.sourceName) → \(outcome.targetName) · 本地翻译引擎"
        textView.string = outcome.text
        replaceButton.title = replaceTitle
        onReplace = replaceHandler
        center()
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func copyTapped() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(textView.string, forType: .string)
    }

    @objc private func replaceTapped() { onReplace?() }
    @objc private func closeTapped() { orderOut(nil) }
}
