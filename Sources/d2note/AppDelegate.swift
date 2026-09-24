import AppKit
import Translation

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, TabBarDelegate, NSMenuDelegate, NSMenuItemValidation {

    // MARK: - Chrome
    var window: NSWindow!
    private var tabBar: TabBarView!
    private var docHost: NSView!
    private var statusBar: StatusBarView!
    private var findBar: FindBarView!
    private var goToBar: GoToBarView!
    private var palettePanel: CommandPalettePanel?
    private var paletteCommands: [CommandItem] = []
    private var findHeight: NSLayoutConstraint!
    private var gotoHeight: NSLayoutConstraint!

    // MARK: - State
    private(set) var documents: [EditorDocument] = []
    private var pendingOpenURLs: [URL] = []
    private var activeIndex = 0
    private var untitledCounter = 1
    private var retokenizeTimer: Timer?

    // Find state
    private var findMatches: [NSRange] = []
    private var findCurrentIndex = -1
    private var findHighlightRanges: [NSRange] = []
    private var findBarVisible: Bool { !findBar.isHidden }

    var activeDoc: EditorDocument? {
        documents.indices.contains(activeIndex) ? documents[activeIndex] : nil
    }

    private var currentFont: NSFont {
        NSFont.monospacedSystemFont(ofSize: CGFloat(Prefs.fontSize), weight: .regular)
    }

    // MARK: - Lifecycle


    func applicationDidFinishLaunching(_ notification: Notification) {
        buildWindow()
        buildMenu()

        NotificationCenter.default.addObserver(
            self, selector: #selector(handleOpenURLsNotification(_:)),
            name: .swiftPadOpenURLs, object: nil
        )
        NotificationCenter.default.addObserver(
            forName: NSTextView.didChangeSelectionNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let self, let tv = note.object as? NSTextView, tv === self.activeDoc?.textView else { return }
            self.selectionChanged()
        }

        applyTheme()
        openInitialContent()
        applyTheme()
        window.collectionBehavior = [.fullScreenPrimary, .fullScreenAuxiliary]

        // 回放启动前收到的打开请求
        if !pendingOpenURLs.isEmpty {
            let queued = pendingOpenURLs
            pendingOpenURLs = []
            openURLs(queued)
        }

        // A saved frame may point to a disconnected display — pull it back on-screen.
        let frame = window.frame
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            for (i, w) in NSApp.windows.enumerated() {
                fputs("SPWIN\(i): visible=\(w.isVisible) occl=\(w.occlusionState.rawValue) frame=\(NSStringFromRect(w.frame)) title=\(w.title)\n", stderr)
            }
            fputs("SPWIN app hidden=\(NSApp.isHidden) windows=\(NSApp.windows.count)\n", stderr)
        }

        NSApp.servicesProvider = self


        if ProcessInfo.processInfo.environment["SP_TEST_PALETTE"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.togglePalette(nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    let wins = NSApp.windows.map { "frame=\(NSStringFromRect($0.frame)) visible=\($0.isVisible) title=\($0.title)" }
                    try? wins.joined(separator: "\n").write(toFile: "/tmp/d2note_wins.log", atomically: true, encoding: .utf8)
                }
            }
        }

        if ProcessInfo.processInfo.environment["SP_TEST_TRANSLATE"] == "1" {
            translationSelfTest = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.translateAction(nil)
            }
        }
    }

    // MARK: - System integration (Dock menu / Services / badge)

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        let new = NSMenuItem(title: "新建标签", action: #selector(newTab(_:)), keyEquivalent: "")
        new.target = self
        menu.addItem(new)
        let open = NSMenuItem(title: "打开…", action: #selector(openDocument(_:)), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        let recents = recents.prefix(5)
        if !recents.isEmpty {
            menu.addItem(.separator())
            for path in recents {
                let item = NSMenuItem(title: (path as NSString).lastPathComponent,
                                      action: #selector(openRecentFile(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = path
                menu.addItem(item)
            }
        }
        return menu
    }

    /// Services handler: "用 d2note 打开所选文本"
    @objc func openSelectedTextService(_ pboard: NSPasteboard, userData: String?, error: NSErrorPointer) {
        guard let text = pboard.string(forType: .string),
              !text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty else { return }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            for (i, w) in NSApp.windows.enumerated() {
                fputs("SPWIN\(i): visible=\(w.isVisible) occl=\(w.occlusionState.rawValue) frame=\(NSStringFromRect(w.frame)) title=\(w.title)\n", stderr)
            }
            fputs("SPWIN app hidden=\(NSApp.isHidden) windows=\(NSApp.windows.count)\n", stderr)
        }
        let doc = newUntitledTab()
        doc.displayTitle = String(text.prefix(24)).replacingOccurrences(of: "\n", with: " ")
        let lang = SourceLanguage.detect(url: nil, content: text)
        doc.language = lang
        doc.textView.language = lang
        doc.textView.insertText(text, replacementRange: EditorTextView.noRange)
        retokenize(doc)
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    func application(_ application: NSApplication, open urls: [URL]) {
        // 通过 Finder 双击/“打开方式”启动时，该 Apple Event 会先于
        // applicationDidFinishLaunching（窗口尚未创建）到达 —— 入队，
        // 等启动完成后再回放，否则 refreshChrome 解包 nil window 崩溃。
        guard window != nil else {
            pendingOpenURLs.append(contentsOf: urls)
            return
        }
        openURLs(urls)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        saveSessionNow()
        SuggestionEngine.shared.save()
        return .terminateNow
    }

    private func openInitialContent() {
        let args = CommandLine.arguments
        if let idx = args.firstIndex(of: "--open"), idx + 1 < args.count {
            var paths: [String] = []
            var i = idx + 1
            while i < args.count, !args[i].hasPrefix("--") {
                paths.append(args[i])
                i += 1
            }
            let urls = paths.map { URL(fileURLWithPath: $0) }
            if !urls.isEmpty {
                openURLs(urls)
                return
            }
        }
        if restoreSession() { return }

        if args.contains("--demo") || !Prefs.firstRunDone {
            loadWelcomeSamples()
            Prefs.firstRunDone = true
            return
        }
        newUntitledTab()
    }

    // MARK: - Session restore / draft autosave

    /// Reopens the last session. Returns false when there is nothing to restore.
    @discardableResult
    private func restoreSession() -> Bool {
        guard let saved = SessionStore.shared.load(), !saved.tabs.isEmpty else { return false }
        var restored = 0
        for tab in saved.tabs {
            let caret = max(0, tab.caret)
            if let path = tab.path {
                let url = URL(fileURLWithPath: path)
                if let loaded = try? loadFile(at: url) {
                    let doc = makeDocument(content: loaded.text, url: url)
                    doc.encoding = loaded.encoding
                    doc.hadBOM = loaded.hadBOM
                    if let draft = tab.draft {
                        doc.isLoadingContent = true
                        doc.textView.string = draft
                        doc.isLoadingContent = false
                        doc.isDirty = true
                        doc.textView.setSelectedRange(NSRange(location: min(caret, (draft as NSString).length), length: 0))
                    }
                    documents.append(doc)
                    restored += 1
                    continue
                }
                // file vanished but a draft exists — rescue it as an untitled tab
                guard let draft = tab.draft, !draft.isEmpty else { continue }
                let doc = makeDocument(content: draft, url: nil)
                doc.displayTitle = url.lastPathComponent + "（已恢复）"
                let lang = SourceLanguage.detect(url: url, content: draft)
                doc.language = lang
                doc.textView.language = lang
                doc.isDirty = true
                doc.textView.setSelectedRange(NSRange(location: min(caret, (draft as NSString).length), length: 0))
                documents.append(doc)
                restored += 1
            } else {
                let doc = makeDocument(content: tab.draft ?? "", url: nil)
                doc.displayTitle = tab.title
                if let draft = tab.draft, !draft.isEmpty {
                    doc.isDirty = true
                    doc.textView.setSelectedRange(NSRange(location: min(caret, (draft as NSString).length), length: 0))
                }
                documents.append(doc)
                restored += 1
            }
        }
        guard restored > 0 else { return false }
        switchToTab(min(max(0, saved.activeIndex), documents.count - 1))
        if let doc = activeDoc {
            let caret = doc.textView.selectedRange()
            doc.textView.scrollRangeToVisible(caret)
        }
        return true
    }

    private var sessionSaveTimer: Timer?

    private func scheduleSessionSave() {
        guard Prefs.autoSaveDrafts else { return }
        sessionSaveTimer?.invalidate()
        sessionSaveTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            self?.saveSessionNow()
            self?.flashDraftSaved()
        }
    }

    private func flashDraftSaved() {
        statusBar.statsLabel.stringValue += " · ✓ 已自动保存"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.updateStatusBar()
        }
    }

    func saveSessionNow() {
        guard Prefs.autoSaveDrafts else { return }
        var tabs: [SavedTab] = []
        for doc in documents where !doc.excludedFromSession {
            let caret = doc.textView.selectedRange().location
            if let url = doc.fileURL {
                tabs.append(SavedTab(path: url.path, title: nil,
                                     draft: doc.isDirty ? doc.textView.string : nil, caret: caret))
            } else {
                tabs.append(SavedTab(path: nil, title: doc.displayTitle != "未命名" ? doc.displayTitle : nil,
                                     draft: doc.textView.string, caret: caret))
            }
        }
        guard !tabs.isEmpty else { return }
        SessionStore.shared.save(SavedSession(tabs: tabs, activeIndex: activeIndex))
    }

    private func loadWelcomeSamples() {
        for (name, content) in SampleContent.files {
            let doc = makeDocument(content: content, url: nil)
            let lang = SourceLanguage.detect(url: URL(fileURLWithPath: name), content: content)
            doc.language = lang
            doc.textView.language = lang
            doc.displayTitle = name
            doc.isDirty = false
            documents.append(doc)
        }
        switchToTab(0)
    }

    // MARK: - Window construction

    private func buildWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 740),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = "d2note"
        window.delegate = self
        window.minSize = NSSize(width: 640, height: 420)
        window.setFrameAutosaveName("d2noteMainWindow")

        let content = NSView()
        window.contentView = content

        tabBar = TabBarView()
        tabBar.delegate = self

        docHost = NSView()

        statusBar = StatusBarView()
        statusBar.onLanguageChanged = { [weak self] lang in
            guard let doc = self?.activeDoc else { return }
            doc.language = lang
            doc.languageLocked = true
            self?.retokenize(doc)
        }
        statusBar.onTranslate = { [weak self] in self?.translateAction(nil) }

        findBar = FindBarView()
        findBar.onFindNext = { [weak self] in self?.findNext() }
        findBar.onFindPrev = { [weak self] in self?.findPrev() }
        findBar.onQueryChanged = { [weak self] in self?.refreshFindFromUI() }
        findBar.onClose = { [weak self] in self?.hideFind() }
        findBar.onReplace = { [weak self] in self?.replaceCurrent() }
        findBar.onReplaceAll = { [weak self] in self?.replaceAll() }
        findBar.onOptionsChanged = { [weak self] in self?.refreshFindFromUI() }

        goToBar = GoToBarView()
        goToBar.onGo = { [weak self] n in
            guard let self else { return }
            self.hideGoTo()
            guard let doc = self.activeDoc else { return }
            let range = doc.rangeOfLine(n)
            doc.textView.setSelectedRange(range)
            doc.textView.scrollRangeToVisible(range)
            self.window.makeFirstResponder(doc.textView)
        }
        goToBar.onClose = { [weak self] in self?.hideGoTo() }

        content.addSubview(tabBar)
        content.addSubview(docHost)
        content.addSubview(statusBar)
        content.addSubview(findBar)
        content.addSubview(goToBar)

        let chromeViews: [NSView] = [tabBar, docHost, statusBar, findBar, goToBar]
        for v in chromeViews {
            v.translatesAutoresizingMaskIntoConstraints = false
        }
        findBar.isHidden = true
        goToBar.isHidden = true

        NSLayoutConstraint.activate([
            tabBar.topAnchor.constraint(equalTo: content.topAnchor),
            tabBar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            tabBar.heightAnchor.constraint(equalToConstant: 36),

            statusBar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            statusBar.heightAnchor.constraint(equalToConstant: 26),

            docHost.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            docHost.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            docHost.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            docHost.bottomAnchor.constraint(equalTo: statusBar.topAnchor),

            findBar.topAnchor.constraint(equalTo: content.topAnchor, constant: 36),
            findBar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            findBar.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            goToBar.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -26),
            goToBar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            goToBar.trailingAnchor.constraint(equalTo: content.trailingAnchor),

        ])
        findHeight = findBar.heightAnchor.constraint(equalToConstant: 0)
        findHeight.isActive = true
        gotoHeight = goToBar.heightAnchor.constraint(equalToConstant: 0)
        gotoHeight.isActive = true
    }

    private func runPaletteAction(_ action: @escaping () -> Void) {
        action()
    }

    private func makeCommands() -> [CommandItem] {
        func c(_ t: String, _ k: String, _ a: @escaping () -> Void) -> CommandItem {
            CommandItem(title: t, key: k, handler: { [weak self] in
                DispatchQueue.main.async { self?.runPaletteAction(a) }
            })
        }
        return [
            c("新建标签", "⌘N", { self.newTab(nil) }),
            c("打开文件…", "⌘O", { self.openDocument(nil) }),
            c("保存", "⌘S", { self.saveDocument(nil) }),
            c("另存为…", "⌘⇧S", { self.saveDocumentAs(nil) }),
            c("保存全部", "⌥⌘S", { self.saveAllDocuments(nil) }),
            c("关闭标签", "⌘W", { self.closeTabAction(nil) }),
            c("查找…", "⌘F", { self.startFind(nil) }),
            c("替换…", "⌥⌘F", { self.startReplace(nil) }),
            c("跳转到行…", "⌘L", { self.goToLine(nil) }),
            c("翻译全文 / 所选…", "⌥⌘T", { self.translateAction(nil) }),
            c("切换注释", "⌘/", { self.toggleComment(nil) }),
            c("格式化文档（智能缩进）", "⌥⇧F", { self.formatDocument(nil) }),
            c("格式化 JSON", "⌘⇧J", { self.formatJSONAction(nil) }),
            c("压缩 JSON", "", { self.minifyJSONAction(nil) }),
            c("格式化 XML / HTML", "", { self.formatXMLAction(nil) }),
            c("压缩 XML / HTML", "", { self.minifyXMLAction(nil) }),
            c("美化 SQL", "", { self.beautifySQLAction(nil) }),
            c("排序所选行", "", { self.sortLinesAction(nil) }),
            c("行倒序", "", { self.reverseLinesAction(nil) }),
            c("去除重复行", "", { self.dedupeLinesAction(nil) }),
            c("删除空行", "", { self.removeEmptyLinesAction(nil) }),
            c("转为大写", "", { self.uppercaseAction(nil) }),
            c("转为小写", "", { self.lowercaseAction(nil) }),
            c("制表符转空格", "", { self.tabsToSpacesAction(nil) }),
            c("去除行尾空白", "", { self.trimTrailingAction(nil) }),
            c("切换：自动换行", "⌥⌘W", { self.toggleWordWrap(nil) }),
            c("切换：行号", "⌥⌘L", { self.toggleLineNumbers(nil) }),
            c("切换：智能推荐", "", { self.toggleSmartSuggest(nil) }),
            c("学习当前文档", "", { self.learnCurrentDocument(nil) }),
            c("主题：深色", "", { self.useDarkTheme(nil) }),
            c("主题：浅色", "", { self.useLightTheme(nil) }),
            c("放大字号", "⌘=", { self.increaseFont(nil) }),
            c("缩小字号", "⌘-", { self.decreaseFont(nil) }),
            c("重置字号", "⌘0", { self.resetFont(nil) }),
            c("下一个标签", "⌘⇧]", { self.nextTab(nil) }),
            c("上一个标签", "⌘⇧[", { self.prevTab(nil) }),
            c("偏好设置…", "⌘,", { self.showSettings(nil) }),
        ]
    }

    @objc func togglePalette(_ sender: Any?) {
        if palettePanel == nil {
            paletteCommands = makeCommands()
            palettePanel = CommandPalettePanel(commands: paletteCommands, onClose: { [weak self] in
                guard let self, let doc = self.activeDoc else { return }
                self.window.makeFirstResponder(doc.textView)
            }, onRun: { [weak self] cmd in
                guard let self else { return }
                self.palettePanel?.orderOut(nil)
                DispatchQueue.main.async { cmd.handler() }
            })
        }
        palettePanel?.present(relativeTo: window)
    }




    // MARK: - Menu

    private func buildMenu() {
        let main = NSMenu()

        // App menu
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        addMenuItems(appMenu, [
            MenuItemDef("关于 d2note", #selector(showAbout(_:))),
            MenuItemDef("-"),
            MenuItemDef("偏好设置…", #selector(showSettings(_:)), ",", [.command]),
            MenuItemDef("-"),
            MenuItemDef("隐藏 d2note", Selector(("hide:")), "h", [.command]),
            MenuItemDef("隐藏其他", Selector(("hideOtherApplications:")), "h", [.command, .option]),
            MenuItemDef("全部显示", Selector(("unhideAllApplications:"))),
            MenuItemDef("-"),
            MenuItemDef("退出 d2note", Selector(("terminate:")), "q", [.command]),
        ])

        // File
        let fileItem = NSMenuItem()
        main.addItem(fileItem)
        let fileMenu = NSMenu(title: "文件")
        fileItem.submenu = fileMenu
        addMenuItems(fileMenu, [
            MenuItemDef("新建标签", #selector(newTab(_:)), "n", [.command]),
            MenuItemDef("打开…", #selector(openDocument(_:)), "o", [.command]),
        ])
        let recentsItem = NSMenuItem(title: "最近打开", action: nil, keyEquivalent: "")
        let recentsMenu = NSMenu(title: "最近打开")
        recentsMenu.delegate = self
        recentsItem.submenu = recentsMenu
        fileMenu.addItem(recentsItem)
        addMenuItems(fileMenu, [
            MenuItemDef("-"),
            MenuItemDef("保存", #selector(saveDocument(_:)), "s", [.command]),
            MenuItemDef("另存为…", #selector(saveDocumentAs(_:)), "s", [.command, .shift]),
            MenuItemDef("保存全部", #selector(saveAllDocuments(_:)), "s", [.command, .option]),
            MenuItemDef("-"),
            MenuItemDef("关闭标签", #selector(closeTabAction(_:)), "w", [.command]),
        ])

        // Edit
        let editItem = NSMenuItem()
        main.addItem(editItem)
        let editMenu = NSMenu(title: "编辑")
        editItem.submenu = editMenu
        addMenuItems(editMenu, [
            MenuItemDef("撤销", Selector(("undo:")), "z", [.command]),
            MenuItemDef("重做", Selector(("redo:")), "z", [.command, .shift]),
            MenuItemDef("-"),
            MenuItemDef("剪切", Selector(("cut:")), "x", [.command]),
            MenuItemDef("拷贝", Selector(("copy:")), "c", [.command]),
            MenuItemDef("粘贴", Selector(("paste:")), "v", [.command]),
            MenuItemDef("全选", Selector(("selectAll:")), "a", [.command]),
            MenuItemDef("-"),
            MenuItemDef("查找…", #selector(startFind(_:)), "f", [.command]),
            MenuItemDef("查找下一个", #selector(findNextAction(_:)), "g", [.command]),
            MenuItemDef("查找上一个", #selector(findPrevAction(_:)), "g", [.command, .shift]),
            MenuItemDef("替换…", #selector(startReplace(_:)), "f", [.command, .option]),
            MenuItemDef("-"),
            MenuItemDef("切换注释", #selector(toggleComment(_:)), "/", [.command]),
        ])

        // Format
        let formatItem = NSMenuItem()
        main.addItem(formatItem)
        let formatMenu = NSMenu(title: "格式")
        formatItem.submenu = formatMenu
        addMenuItems(formatMenu, [
            MenuItemDef("格式化文档（智能缩进）", #selector(formatDocument(_:)), "f", [.command, .shift, .option]),
            MenuItemDef("格式化 JSON", #selector(formatJSONAction(_:)), "j", [.command, .shift]),
            MenuItemDef("压缩 JSON", #selector(minifyJSONAction(_:))),
            MenuItemDef("格式化 XML / HTML", #selector(formatXMLAction(_:))),
            MenuItemDef("压缩 XML / HTML", #selector(minifyXMLAction(_:))),
            MenuItemDef("美化 SQL", #selector(beautifySQLAction(_:))),
            MenuItemDef("-"),
            MenuItemDef("排序所选行", #selector(sortLinesAction(_:))),
            MenuItemDef("行倒序", #selector(reverseLinesAction(_:))),
            MenuItemDef("去除重复行", #selector(dedupeLinesAction(_:))),
            MenuItemDef("删除空行", #selector(removeEmptyLinesAction(_:))),
            MenuItemDef("转为大写", #selector(uppercaseAction(_:))),
            MenuItemDef("转为小写", #selector(lowercaseAction(_:))),
            MenuItemDef("制表符转空格", #selector(tabsToSpacesAction(_:))),
            MenuItemDef("-"),
            MenuItemDef("去除行尾空白", #selector(trimTrailingAction(_:))),
        ])

        // View
        let viewItem = NSMenuItem()
        main.addItem(viewItem)
        let viewMenu = NSMenu(title: "显示")
        viewItem.submenu = viewMenu
        addMenuItems(viewMenu, [
            MenuItemDef("行号", #selector(toggleLineNumbers(_:)), "l", [.command, .option]),
            MenuItemDef("自动换行", #selector(toggleWordWrap(_:)), "w", [.command, .option]),
            MenuItemDef("-"),
            MenuItemDef("深色主题", #selector(useDarkTheme(_:))),
            MenuItemDef("浅色主题", #selector(useLightTheme(_:))),
            MenuItemDef("-"),
            MenuItemDef("放大字号", #selector(increaseFont(_:)), "=", [.command]),
            MenuItemDef("缩小字号", #selector(decreaseFont(_:)), "-", [.command]),
            MenuItemDef("重置字号", #selector(resetFont(_:)), "0", [.command]),
        ])

        // Go
        let goItem = NSMenuItem()
        main.addItem(goItem)
        let goMenu = NSMenu(title: "前往")
        goItem.submenu = goMenu
        addMenuItems(goMenu, [
            MenuItemDef("跳转到行…", #selector(goToLine(_:)), "l", [.command]),
            MenuItemDef("-"),
            MenuItemDef("下一个标签", #selector(nextTab(_:)), "]", [.command, .shift]),
            MenuItemDef("上一个标签", #selector(prevTab(_:)), "[", [.command, .shift]),
        ])
        addMenuItem(goMenu, MenuItemDef("命令面板", #selector(togglePalette(_:)), "p", [.command, .shift]), target: self)
        for i in 1...9 {
            let item = NSMenuItem(title: "标签 \(i)", action: #selector(selectTabByIndex(_:)), keyEquivalent: "\(i)")
            item.tag = i - 1
            goMenu.addItem(item)
        }

        // Window
        let windowItem = NSMenuItem()
        main.addItem(windowItem)
        let windowMenu = NSMenu(title: "窗口")
        windowItem.submenu = windowMenu
        addMenuItems(viewMenu, [
            MenuItemDef("-"),
            MenuItemDef("进入全屏", Selector(("toggleFullScreen:")), "f", [.command, .control]),
        ])

        // Tools (local intelligence)
        let toolsItem = NSMenuItem()
        main.addItem(toolsItem)
        let toolsMenu = NSMenu(title: "工具")
        toolsItem.submenu = toolsMenu
        addMenuItems(toolsMenu, [
            MenuItemDef("翻译全文 / 所选…", #selector(translateAction(_:)), "t", [.command, .option]),
            MenuItemDef("-"),
            MenuItemDef("智能推荐（本机习惯学习）", #selector(toggleSmartSuggest(_:))),
            MenuItemDef("学习当前文档", #selector(learnCurrentDocument(_:))),
        ])

        NSApp.mainMenu = main
    }

    private func addMenuItems(_ menu: NSMenu, _ defs: [MenuItemDef]) {
        for def in defs {
            if def.title == "-" {
                menu.addItem(.separator())
            } else {
                let item = NSMenuItem(title: def.title, action: def.action, keyEquivalent: def.key)
                item.keyEquivalentModifierMask = def.mods
                menu.addItem(item)
            }
        }
    }

    private func addMenuItem(_ menu: NSMenu, _ def: MenuItemDef, target: AnyObject?) {
        let item = NSMenuItem(title: def.title, action: def.action, keyEquivalent: def.key)
        item.keyEquivalentModifierMask = def.mods
        item.target = target
        menu.addItem(item)
    }

    private struct MenuItemDef {
        let title: String
        let action: Selector?
        let key: String
        let mods: NSEvent.ModifierFlags
        init(_ title: String, _ action: Selector? = nil, _ key: String = "", _ mods: NSEvent.ModifierFlags = []) {
            self.title = title
            self.action = action
            self.key = key
            self.mods = mods
        }
    }

    // MARK: - Document management

    @discardableResult
    private func newUntitledTab() -> EditorDocument {
        let doc = makeDocument(content: "", url: nil)
        doc.untitledNumber = untitledCounter
        untitledCounter += 1
        documents.append(doc)
        switchToTab(documents.count - 1)
        return doc
    }

    private func makeDocument(content: String, url: URL?) -> EditorDocument {
        let tv = EditorTextView()
        tv.indentUnit = String(repeating: " ", count: Prefs.tabWidth)
        tv.autoClosePairs = Prefs.autoClosePairs
        tv.language = SourceLanguage.detect(url: url, content: content)

        let ruler = LineNumberRulerView(scrollView: NSScrollView(), editor: tv)
        let sv = NSScrollView()
        sv.hasVerticalScroller = true
        sv.autohidesScrollers = true
        sv.borderType = .noBorder
        sv.drawsBackground = true
        sv.documentView = tv
        sv.hasVerticalRuler = true
        sv.rulersVisible = Prefs.lineNumbers
        sv.verticalRulerView = ruler
        sv.contentView.automaticallyAdjustsContentInsets = true

        let doc = EditorDocument(textView: tv, scrollView: sv, ruler: ruler)
        doc.language = tv.language
        doc.fileURL = url
        doc.textView.onTextChanged = { [weak self, weak doc] in
            guard let self, let doc else { return }
            self.handleTextChange(doc)
        }
        doc.textView.fileDropHandler = { [weak self] urls in
            self?.openURLs(urls)
        }
        doc.textView.onEscape = { [weak self] in
            if self?.findBarVisible == true { self?.hideFind() }
            if self?.goToBar.isHidden == false { self?.hideGoTo() }
        }
        doc.textView.onLineCommitted = { line in
            SuggestionEngine.shared.record(line: line)
        }
        doc.dirtyHandler = { [weak self] _ in
            self?.refreshChrome()
        }
        ruler.lineStartsProvider = { [weak doc] in doc?.lineStartOffsets() ?? [] }
        ruler.currentLineProvider = { [weak doc] in
            guard let doc else { return -1 }
            return doc.lineAndColumn(at: doc.textView.selectedRange().location).line - 1
        }

        doc.isLoadingContent = true
        tv.string = content
        doc.isLoadingContent = false
        tv.setSelectedRange(NSRange(location: 0, length: 0))
        tv.setWordWrap(Prefs.wordWrap)
        tv.applyTheme(Theme.current, font: currentFont)
        ruler.applyTheme(Theme.current)
        return doc
    }

    func openURLs(_ urls: [URL]) {
        fputs("SPDEBUG openURLs count=\(urls.count)\n", stderr)
        for url in urls {
            if let existing = documents.firstIndex(where: { $0.fileURL == url }) {
                switchToTab(existing)
                continue
            }
            do {
                let loaded = try loadFile(at: url)
                let doc = makeDocument(content: loaded.text, url: url)
                doc.encoding = loaded.encoding
                doc.hadBOM = loaded.hadBOM
                doc.isDirty = false
                documents.append(doc)
                switchToTab(documents.count - 1)
                addRecent(url)
            } catch {
                fputs("SPDEBUG openURLs FAILED \(url.path): \(error.localizedDescription)\n", stderr)
                let alert = NSAlert()
                alert.messageText = "无法打开文件"
                alert.informativeText = "\(url.lastPathComponent)：\(error.localizedDescription)"
                alert.runModal()
            }
        }
        window.makeKeyAndOrderFront(nil)
    }

    private struct LoadedFile {
        let text: String
        let encoding: String.Encoding
        let hadBOM: Bool
    }

    private func loadFile(at url: URL) throws -> LoadedFile {
        let data = try Data(contentsOf: url)
        if isBinaryData(data) {
            throw NSError(domain: "d2note", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "看起来是二进制文件，无法作为文本打开。"
            ])
        }
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            let body = data.dropFirst(3)
            return LoadedFile(text: String(decoding: body, as: UTF8.self), encoding: .utf8, hadBOM: true)
        }
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) {
            let enc: String.Encoding = data.starts(with: [0xFF, 0xFE]) ? .utf16LittleEndian : .utf16BigEndian
            let text = String(data: data, encoding: enc) ?? String(decoding: data, as: UTF8.self)
            return LoadedFile(text: text, encoding: enc, hadBOM: false)
        }
        if let s = String(data: data, encoding: .utf8) {
            return LoadedFile(text: s, encoding: .utf8, hadBOM: false)
        }
        let latin = String(data: data, encoding: .isoLatin1) ?? String(decoding: data, as: UTF8.self)
        return LoadedFile(text: latin, encoding: .isoLatin1, hadBOM: false)
    }

    private func isBinaryData(_ data: Data) -> Bool {
        let sample = data.prefix(8192)
        var zeros = 0
        for byte in sample where byte == 0 { zeros += 1 }
        return zeros > 0
    }

    // MARK: - Tab switching / chrome refresh

    func switchToTab(_ index: Int) {
        guard documents.indices.contains(index) else { return }
        activeIndex = index
        let doc = documents[index]
        docHost.subviews.forEach { $0.removeFromSuperview() }
        docHost.addSubview(doc.scrollView)
        doc.scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            doc.scrollView.topAnchor.constraint(equalTo: docHost.topAnchor),
            doc.scrollView.bottomAnchor.constraint(equalTo: docHost.bottomAnchor),
            doc.scrollView.leadingAnchor.constraint(equalTo: docHost.leadingAnchor),
            doc.scrollView.trailingAnchor.constraint(equalTo: docHost.trailingAnchor),
        ])
        window.makeFirstResponder(doc.textView)
        if doc.needsRetokenize { retokenize(doc) }
        doc.ruler.updateThickness()
        refreshChrome()
        updateStatusBar()
        scheduleSessionSave()
    }

    private func refreshChrome() {
        guard window != nil, tabBar != nil else { return }
        tabBar.needsDisplay = true
        if let doc = activeDoc {
            window.title = "\(doc.displayName) — d2note"
            window.isDocumentEdited = doc.isDirty
            window.representedURL = doc.fileURL
        } else {
            window.title = "d2note"
            window.isDocumentEdited = false
            window.representedURL = nil
        }
        let dirtyCount = documents.filter(\.isDirty).count
        NSApp.dockTile.badgeLabel = dirtyCount > 0 ? "\(dirtyCount)" : nil
    }

    private func updateStatusBar() {
        guard let doc = activeDoc else {
            statusBar.update(position: "", stats: "", spaces: Prefs.tabWidth, encoding: "UTF-8", language: .plain)
            return
        }
        let sel = doc.textView.selectedRange()
        let (line, col) = doc.lineAndColumn(at: sel.location)
        let chars = (doc.textView.string as NSString).length
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let charsStr = formatter.string(from: NSNumber(value: chars)) ?? "\(chars)"
        let stats = "\(charsStr) 字符 · \(doc.wordCount()) 词 · \(doc.lineCount) 行"
        let enc: String
        switch doc.encoding {
        case .utf8: enc = doc.hadBOM ? "UTF-8 BOM" : "UTF-8"
        case .utf16LittleEndian: enc = "UTF-16 LE"
        case .utf16BigEndian: enc = "UTF-16 BE"
        case .isoLatin1: enc = "Latin-1"
        default: enc = "UTF-8"
        }
        statusBar.update(position: "Ln \(line), Col \(col)", stats: stats,
                         spaces: Prefs.tabWidth, encoding: enc, language: doc.language)
    }

    private func selectionChanged() {
        guard let doc = activeDoc else { return }
        doc.textView.updateOverlays(theme: Theme.current)
        doc.ruler.needsDisplay = true
        doc.textView.updateGhostSuggestion()
        updateStatusBar()
    }

    private func handleTextChange(_ doc: EditorDocument) {
        guard !doc.isLoadingContent else { return }
        doc.isDirty = true
        doc.invalidateLineCache()
        doc.ruler.needsDisplay = true
        doc.ruler.updateThickness()
        doc.textView.updateOverlays(theme: Theme.current)
        doc.textView.updateGhostSuggestion()
        scheduleRetokenize()
        scheduleSessionSave()
        updateStatusBar()
        if findBarVisible {
            scheduleFindRefresh()
        }
    }

    private func scheduleRetokenize() {
        retokenizeTimer?.invalidate()
        retokenizeTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: false) { [weak self] _ in
            guard let self, let doc = self.activeDoc else { return }
            self.retokenize(doc)
        }
    }

    private func retokenize(_ doc: EditorDocument) {
        doc.needsRetokenize = false
        guard let storage = doc.textView.textStorage else { return }
        let text = doc.textView.string
        let tokens = text.utf16.count > 2_000_000 ? [] : Tokenizer.tokenize(text, language: doc.language)
        Highlighter.apply(to: storage, tokens: tokens, theme: Theme.current, font: currentFont)
        doc.textView.updateOverlays(theme: Theme.current)
    }

    // MARK: - Theme / preferences application

    private func applyTheme() {
        let theme = Theme.current
        window.appearance = NSAppearance(named: theme.isDark ? .darkAqua : .aqua)
        window.backgroundColor = theme.editorBackground
        tabBar.theme = theme
        statusBar.theme = theme
        for doc in documents {
            doc.textView.applyTheme(theme, font: currentFont)
            doc.scrollView.backgroundColor = theme.editorBackground
            doc.ruler.applyTheme(theme)
            if doc.needsRetokenize == false { retokenize(doc) }
        }
        refreshChrome()
    }

    private func applyFontToAll() {
        let font = currentFont
        for doc in documents {
            doc.textView.font = font
            doc.ruler.needsDisplay = true
            retokenize(doc)
        }
    }

    private func applyPrefsToAll() {
        for doc in documents {
            doc.textView.indentUnit = String(repeating: " ", count: Prefs.tabWidth)
            doc.textView.autoClosePairs = Prefs.autoClosePairs
            doc.textView.setWordWrap(Prefs.wordWrap)
            doc.scrollView.rulersVisible = Prefs.lineNumbers
        }
        applyFontToAll()
        updateStatusBar()
    }

    // MARK: - TabBarDelegate

    func numberOfTabs() -> Int { documents.count }
    func tabTitle(_ index: Int) -> String { documents.indices.contains(index) ? documents[index].displayName : "" }
    func tabIsDirty(_ index: Int) -> Bool { documents.indices.contains(index) ? documents[index].isDirty : false }
    func tabLanguage(_ index: Int) -> SourceLanguage { documents.indices.contains(index) ? documents[index].language : .plain }
    func tabToolTip(_ index: Int) -> String? { documents.indices.contains(index) ? documents[index].fileURL?.path : nil }
    func activeTabIndex() -> Int { activeIndex }

    func tabBarDidSelect(_ index: Int) {
        if index != activeIndex { switchToTab(index) }
    }

    func tabBarDidClose(_ index: Int) {
        guard documents.indices.contains(index) else { return }
        let doc = documents[index]
        if doc.isDirty {
            let alert = NSAlert()
            alert.messageText = "要保存对“\(doc.displayName)”的更改吗？"
            alert.informativeText = "如果不保存，更改将会丢失。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "保存")
            alert.addButton(withTitle: "不保存")
            alert.addButton(withTitle: "取消")
            alert.beginSheetModal(for: window) { [weak self] resp in
                switch resp {
                case .alertFirstButtonReturn:
                    self?.saveDocumentAndThenClose(index)
                case .alertSecondButtonReturn:
                    self?.removeTab(index)
                default:
                    break
                }
            }
        } else {
            removeTab(index)
        }
    }

    private func saveDocumentAndThenClose(_ index: Int) {
        guard let doc = documents.indices.contains(index) ? documents[index] : nil else { return }
        if saveDoc(doc) {
            removeTab(index)
        }
    }

    private func removeTab(_ index: Int) {
        documents.remove(at: index)
        saveSessionNow()
        if documents.isEmpty {
            newUntitledTab()
        } else if activeIndex >= documents.count {
            switchToTab(documents.count - 1)
        } else {
            switchToTab(activeIndex >= index ? activeIndex - (index <= activeIndex ? 1 : 0) : activeIndex)
        }
    }

    func tabBarDidClickPlus() { newUntitledTab() }

    func tabBarDidReorder(from: Int, to: Int) {
        guard documents.indices.contains(from), documents.indices.contains(to) else { return }
        let doc = documents.remove(at: from)
        documents.insert(doc, at: to)
        if activeIndex == from {
            activeIndex = to
        } else if from < activeIndex && to >= activeIndex {
            activeIndex -= 1
        } else if from > activeIndex && to <= activeIndex {
            activeIndex += 1
        }
        tabBar.needsDisplay = true
        saveSessionNow()
    }

    // MARK: - File actions

    @objc func newTab(_ sender: Any?) { newUntitledTab() }

    @objc func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.beginSheetModal(for: window) { [weak self] resp in
            guard resp == .OK else { return }
            self?.openURLs(panel.urls)
        }
    }

    @objc private func handleOpenURLsNotification(_ note: Notification) {
        if let urls = note.object as? [URL] { openURLs(urls) }
    }

    @discardableResult
    private func saveDoc(_ doc: EditorDocument) -> Bool {
        if doc.fileURL == nil {
            return runSavePanel(for: doc)
        }
        return writeDoc(doc)
    }

    private func runSavePanel(for doc: EditorDocument) -> Bool {
        let panel = NSSavePanel()
        let suggested = doc.fileURL?.lastPathComponent ?? (doc.displayName + ".txt")
        panel.nameFieldStringValue = suggested
        let result = panel.runModal()
        guard result == .OK, let url = panel.url else { return false }
        doc.fileURL = url
        if !doc.languageLocked {
            doc.language = SourceLanguage.detect(url: url, content: doc.textView.string)
        }
        return writeDoc(doc)
    }

    private func writeDoc(_ doc: EditorDocument) -> Bool {
        guard let url = doc.fileURL else { return false }
        var data = doc.textView.string.data(using: doc.encoding) ?? Data(doc.textView.string.utf8)
        if doc.hadBOM {
            data.insert(contentsOf: [0xEF, 0xBB, 0xBF], at: 0)
        }
        do {
            try data.write(to: url, options: .atomic)
            doc.isDirty = false
            doc.needsRetokenize = false
            addRecent(url)
            refreshChrome()
            updateStatusBar()
            saveSessionNow()
            return true
        } catch {
            let alert = NSAlert()
            alert.messageText = "保存失败"
            alert.informativeText = error.localizedDescription
            alert.runModal()
            return false
        }
    }

    @objc func saveDocument(_ sender: Any?) {
        guard let doc = activeDoc else { return }
        _ = saveDoc(doc)
    }

    @objc func saveDocumentAs(_ sender: Any?) {
        guard let doc = activeDoc else { return }
        _ = runSavePanel(for: doc)
    }

    @objc func saveAllDocuments(_ sender: Any?) {
        for doc in documents where doc.isDirty {
            if doc.fileURL == nil {
                if !runSavePanel(for: doc) { return }
            } else if !writeDoc(doc) {
                return
            }
        }
    }

    @objc func closeTabAction(_ sender: Any?) {
        if activeDoc != nil { tabBarDidClose(activeIndex) }
    }

    // MARK: - Window close with unsaved check

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        let dirty = documents.filter { $0.isDirty }
        guard !dirty.isEmpty else { return true }
        let alert = NSAlert()
        alert.messageText = dirty.count == 1 ? "要保存对“\(dirty[0].displayName)”的更改吗？" : "有 \(dirty.count) 个标签未保存"
        alert.informativeText = "如果不保存，更改将会丢失。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: dirty.count == 1 ? "保存" : "保存全部")
        alert.addButton(withTitle: "不保存")
        alert.addButton(withTitle: "取消")
        alert.beginSheetModal(for: window) { [weak self] resp in
            guard let self else { return }
            switch resp {
            case .alertFirstButtonReturn:
                var aborted = false
                for doc in dirty {
                    if doc.fileURL == nil {
                        if !self.runSavePanel(for: doc) { aborted = true; break }
                    } else if !self.writeDoc(doc) {
                        aborted = true
                        break
                    }
                }
                if !aborted { self.window.close() }
            case .alertSecondButtonReturn:
                for doc in dirty { doc.excludedFromSession = true }
                self.saveSessionNow()
                self.window.close()
            default:
                break
            }
        }
        return false
    }

    // MARK: - Recents

    private var recents: [String] {
        get { UserDefaults.standard.stringArray(forKey: "sp.recents") ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "sp.recents") }
    }

    private func addRecent(_ url: URL) {
        var r = recents
        r.removeAll { $0 == url.path }
        r.insert(url.path, at: 0)
        if r.count > 10 { r = Array(r.prefix(10)) }
        recents = r
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu.title == "最近打开" else { return }
        menu.removeAllItems()
        let items = recents
        if items.isEmpty {
            let item = NSMenuItem(title: "（空）", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            for path in items {
                let item = NSMenuItem(title: (path as NSString).lastPathComponent + "  —  " + (path as NSString).deletingLastPathComponent,
                                      action: #selector(openRecentFile(_:)), keyEquivalent: "")
                item.representedObject = path
                item.toolTip = path
                menu.addItem(item)
            }
            menu.addItem(.separator())
            menu.addItem(NSMenuItem(title: "清除菜单", action: #selector(clearRecents(_:)), keyEquivalent: ""))
        }
    }

    @objc private func openRecentFile(_ sender: NSMenuItem) {
        if let path = sender.representedObject as? String {
            openURLs([URL(fileURLWithPath: path)])
        }
    }

    @objc private func clearRecents(_ sender: Any?) {
        recents = []
    }

    // MARK: - Find & Replace

    @objc func startFind(_ sender: Any?) {
        showFind(replace: false)
    }

    @objc func startReplace(_ sender: Any?) {
        showFind(replace: true)
    }

    private func showFind(replace: Bool) {
        if replace { findBar.replaceVisible = true }
        findBar.isHidden = false
        findHeight.constant = findBar.preferredHeight
        refreshFindFromUI(selectNearest: false)
        if replace { findBar.focusReplace() } else { findBar.focusSearch() }
    }

    @objc func hideFind() {
        findBar.isHidden = true
        findHeight.constant = 0
        clearFindHighlights()
        if let doc = activeDoc {
            window.makeFirstResponder(doc.textView)
        }
    }

    @objc func findNextAction(_ sender: Any?) {
        if findBarVisible { findNext() } else { showFind(replace: false) }
    }

    @objc func findPrevAction(_ sender: Any?) {
        if findBarVisible { findPrev() } else { showFind(replace: false) }
    }

    private func refreshFindFromUI(selectNearest: Bool = true) {
        guard let doc = activeDoc, findBarVisible else { return }
        computeFindMatches(doc)
        applyFindHighlights(doc)
        if selectNearest, !findMatches.isEmpty {
            let caret = doc.textView.selectedRange().location
            let idx = findMatches.firstIndex { NSMaxRange($0) > caret } ?? 0
            selectMatch(idx, doc: doc)
        }
        updateFindCountLabel()
    }

    private var findRefreshTimer: Timer?
    private func scheduleFindRefresh() {
        findRefreshTimer?.invalidate()
        findRefreshTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
            self?.refreshFindFromUI(selectNearest: false)
        }
    }

    private func computeFindMatches(_ doc: EditorDocument) {
        findMatches = []
        findCurrentIndex = -1
        let q = findBar.query
        guard !q.isEmpty else { return }
        let s = doc.textView.string as NSString
        if findBar.isRegex {
            do {
                let regex = try NSRegularExpression(pattern: q, options: findBar.isCaseSensitive ? [] : [.caseInsensitive])
                regex.enumerateMatches(in: doc.textView.string, options: [], range: NSRange(location: 0, length: s.length)) { m, _, _ in
                    if let m { findMatches.append(m.range) }
                }
            } catch {
                findBar.countLabel.stringValue = "无效正则"
                return
            }
        } else {
            let options: String.CompareOptions = findBar.isCaseSensitive ? [] : [.caseInsensitive]
            var searchStart = 0
            let length = s.length
            while searchStart <= length {
                let found = s.range(of: q, options: options, range: NSRange(location: searchStart, length: length - searchStart))
                if found.location == NSNotFound { break }
                findMatches.append(found)
                searchStart = found.location + max(found.length, 1)
            }
        }
    }

    private func updateFindCountLabel() {
        if findBar.query.isEmpty {
            findBar.countLabel.stringValue = ""
        } else if findMatches.isEmpty {
            findBar.countLabel.stringValue = "无结果"
        } else {
            findBar.countLabel.stringValue = "\(findCurrentIndex + 1)/\(findMatches.count)"
        }
    }

    private func selectMatch(_ idx: Int, doc: EditorDocument) {
        guard findMatches.indices.contains(idx) else { return }
        findCurrentIndex = idx
        let r = findMatches[idx]
        doc.textView.setSelectedRange(r)
        doc.textView.scrollRangeToVisible(r)
        updateFindCountLabel()
    }

    private func findNext() {
        guard let doc = activeDoc, !findMatches.isEmpty else { return }
        selectMatch((findCurrentIndex + 1) % findMatches.count, doc: doc)
    }

    private func findPrev() {
        guard let doc = activeDoc, !findMatches.isEmpty else { return }
        selectMatch((findCurrentIndex - 1 + findMatches.count) % findMatches.count, doc: doc)
    }

    private func applyFindHighlights(_ doc: EditorDocument) {
        clearFindHighlights(doc: doc)
        guard let lm = doc.textView.layoutManager else { return }
        for r in findMatches {
            lm.addTemporaryAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, forCharacterRange: r)
            lm.addTemporaryAttribute(.underlineColor, value: Theme.current.findUnderline, forCharacterRange: r)
            findHighlightRanges.append(r)
        }
    }

    private func clearFindHighlights(doc: EditorDocument? = nil) {
        guard let doc = doc ?? activeDoc, let lm = doc.textView.layoutManager else {
            findHighlightRanges = []
            return
        }
        for r in findHighlightRanges {
            lm.removeTemporaryAttribute(.underlineStyle, forCharacterRange: r)
            lm.removeTemporaryAttribute(.underlineColor, forCharacterRange: r)
        }
        findHighlightRanges = []
    }

    private func replaceCurrent() {
        guard let doc = activeDoc, findBarVisible, findMatches.indices.contains(findCurrentIndex) else { return }
        let r = findMatches[findCurrentIndex]
        doc.textView.insertText(findBar.replaceField.stringValue, replacementRange: r)
    }

    private func replaceAll() {
        guard let doc = activeDoc, !findMatches.isEmpty else { return }
        let s = doc.textView.string as NSString
        let replacement = findBar.replaceField.stringValue
        let result = s.mutableCopy() as! NSMutableString
        for r in findMatches.reversed() {
            result.replaceCharacters(in: r, with: replacement)
        }
        doc.textView.insertText(result as String, replacementRange: NSRange(location: 0, length: s.length))
    }

    // MARK: - Go to line

    @objc func goToLine(_ sender: Any?) {
        guard let doc = activeDoc else { return }
        goToBar.isHidden = false
        goToBar.maxLine = doc.lineCount
        gotoHeight.constant = 44
        goToBar.focus()
    }

    private func hideGoTo() {
        goToBar.isHidden = true
        gotoHeight.constant = 0
        if let doc = activeDoc { window.makeFirstResponder(doc.textView) }
    }

    // MARK: - Comment toggle

    @objc func toggleComment(_ sender: Any?) {
        guard let doc = activeDoc else { return }
        let tv = doc.textView
        let s = tv.string as NSString
        let sel = tv.selectedRange()
        let caretLoc = min(sel.location, s.length)
        let firstLine = s.lineRange(for: NSRange(location: caretLoc, length: 0))
        let lastCharLoc = min(s.length, max(caretLoc, sel.location + sel.length)) - 1
        var lastLine = s.lineRange(for: NSRange(location: max(0, lastCharLoc), length: 0))
        var unionEnd = NSMaxRange(lastLine)
        if unionEnd > lastLine.location {
            let lastCh = s.character(at: unionEnd - 1)
            if lastCh == 0x0A || lastCh == 0x0D { unionEnd -= 1 }
        }
        if unionEnd <= firstLine.location { lastLine = firstLine; unionEnd = NSMaxRange(firstLine) }
        if unionEnd > firstLine.location {
            let lastCh = s.character(at: unionEnd - 1)
            if lastCh == 0x0A || lastCh == 0x0D { unionEnd -= 1 }
        }
        let union = NSRange(location: firstLine.location, length: max(0, unionEnd - firstLine.location))
        let block = s.substring(with: union)

        let spec = doc.language.spec
        if let token = spec.lineComments.first {
            var lines = block.components(separatedBy: "\n")
            let nonEmpty = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let allCommented = !nonEmpty.isEmpty && nonEmpty.allSatisfy {
                $0.trimmingCharacters(in: .whitespaces).hasPrefix(token)
            }
            for (i, line) in lines.enumerated() {
                if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
                if allCommented {
                    if let r = line.range(of: token) {
                        var l = line
                        l.removeSubrange(r.lowerBound..<line.index(r.lowerBound, offsetBy: token.utf8.count))
                        if l.hasPrefix(" ") { l.removeFirst() }
                        lines[i] = l
                    }
                } else {
                    let indent = String(line.prefix { $0 == " " || $0 == "\t" })
                    lines[i] = indent + token + " " + line.dropFirst(indent.count)
                }
            }
            tv.insertText(lines.joined(separator: "\n"), replacementRange: union)
        } else if let (open, close) = spec.blockComments.first {
            let commented = open + " " + block + " " + close
            tv.insertText(commented, replacementRange: union)
        } else {
            NSSound.beep()
        }
    }

    // MARK: - Formatting

    private func replaceDocText(_ doc: EditorDocument, with new: String) {
        let tv = doc.textView
        let len = (tv.string as NSString).length
        let oldSel = tv.selectedRange()
        tv.insertText(new, replacementRange: NSRange(location: 0, length: len))
        let newLen = (tv.string as NSString).length
        tv.setSelectedRange(NSRange(location: min(oldSel.location, newLen), length: 0))
        tv.scrollRangeToVisible(tv.selectedRange())
    }

    private func alertFormatError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "格式化失败"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.beginSheetModal(for: window, completionHandler: nil)
    }

    @objc func formatDocument(_ sender: Any?) {
        guard let doc = activeDoc else { return }
        let formatted = Formatter.smartIndent(doc.textView.string, language: doc.language, indentWidth: Prefs.tabWidth)
        replaceDocText(doc, with: formatted)
    }

    @objc func formatJSONAction(_ sender: Any?) {
        guard let doc = activeDoc else { return }
        switch Formatter.formatJSON(doc.textView.string, minify: false) {
        case .success(let out): replaceDocText(doc, with: out)
        case .failure(let err): alertFormatError(err.message)
        }
    }

    @objc func minifyJSONAction(_ sender: Any?) {
        guard let doc = activeDoc else { return }
        switch Formatter.formatJSON(doc.textView.string, minify: true) {
        case .success(let out): replaceDocText(doc, with: out)
        case .failure(let err): alertFormatError(err.message)
        }
    }

    @objc func formatXMLAction(_ sender: Any?) {
        guard let doc = activeDoc else { return }
        switch Formatter.formatXML(doc.textView.string) {
        case .success(let out): replaceDocText(doc, with: out)
        case .failure(let err):
            let formatted = Formatter.smartIndent(doc.textView.string, language: doc.language, indentWidth: Prefs.tabWidth)
            if formatted != doc.textView.string {
                replaceDocText(doc, with: formatted)
            } else {
                alertFormatError(err.message)
            }
        }
    }

    @objc func trimTrailingAction(_ sender: Any?) {
        guard let doc = activeDoc else { return }
        replaceDocText(doc, with: Formatter.trimTrailingWhitespace(doc.textView.string))
    }

    // MARK: - View actions

    @objc func toggleWordWrap(_ sender: Any?) {
        Prefs.wordWrap.toggle()
        applyPrefsToAll()
    }

    @objc func toggleLineNumbers(_ sender: Any?) {
        Prefs.lineNumbers.toggle()
        applyPrefsToAll()
    }

    @objc func useDarkTheme(_ sender: Any?) {
        Theme.current = .dark
        applyTheme()
    }

    @objc func useLightTheme(_ sender: Any?) {
        Theme.current = .light
        applyTheme()
    }

    @objc func increaseFont(_ sender: Any?) {
        Prefs.fontSize = min(32, Prefs.fontSize + 1)
        applyFontToAll()
    }

    @objc func decreaseFont(_ sender: Any?) {
        Prefs.fontSize = max(9, Prefs.fontSize - 1)
        applyFontToAll()
    }

    @objc func resetFont(_ sender: Any?) {
        Prefs.fontSize = 13
        applyFontToAll()
    }

    @objc func nextTab(_ sender: Any?) {
        guard !documents.isEmpty else { return }
        switchToTab((activeIndex + 1) % documents.count)
    }

    @objc func prevTab(_ sender: Any?) {
        guard !documents.isEmpty else { return }
        switchToTab((activeIndex - 1 + documents.count) % documents.count)
    }

    @objc func selectTabByIndex(_ sender: NSMenuItem) {
        let idx = sender.tag
        if documents.indices.contains(idx) { switchToTab(idx) }
    }

    // MARK: - Quick line transforms (选区或全文)

    private func editSelectionOrAll(_ transform: (String) -> String) {
        guard let doc = activeDoc else { return }
        let tv = doc.textView
        let s = tv.string as NSString
        let sel = tv.selectedRange()
        let loc = min(sel.location, s.length)
        let len = min(sel.length, s.length - loc)
        if len > 0 {
            let old = s.substring(with: NSRange(location: loc, length: len))
            let new = transform(old)
            guard new != old else { return }
            tv.insertText(new, replacementRange: NSRange(location: loc, length: len))
        } else {
            let all = tv.string
            let new = transform(all)
            guard new != all else { return }
            replaceDocText(doc, with: new)
        }
    }

    @objc func sortLinesAction(_ sender: Any?) {
        editSelectionOrAll { Formatter.sortLines($0, reverse: false) }
    }

    @objc func reverseLinesAction(_ sender: Any?) {
        editSelectionOrAll { Formatter.reverseLines($0) }
    }

    @objc func dedupeLinesAction(_ sender: Any?) {
        editSelectionOrAll { Formatter.dedupeLines($0) }
    }

    @objc func removeEmptyLinesAction(_ sender: Any?) {
        editSelectionOrAll { Formatter.removeEmptyLines($0) }
    }

    @objc func uppercaseAction(_ sender: Any?) {
        editSelectionOrAll { $0.uppercased() }
    }

    @objc func lowercaseAction(_ sender: Any?) {
        editSelectionOrAll { $0.lowercased() }
    }

    @objc func tabsToSpacesAction(_ sender: Any?) {
        editSelectionOrAll { Formatter.tabsToSpaces($0, width: Prefs.tabWidth) }
    }

    @objc func minifyXMLAction(_ sender: Any?) {
        editSelectionOrAll { Formatter.minifyXMLHTML($0) }
    }

    @objc func beautifySQLAction(_ sender: Any?) {
        editSelectionOrAll { Formatter.beautifySQL($0) }
    }

    // MARK: - Translation (on-device, macOS 26+)

    private var translatePanel: TranslatePanelWindow?
    private var lastTranslation: (doc: EditorDocument, range: NSRange, text: String)? = nil
    private var translateHost: Any? = nil
    private var translationSelfTest = false

    @objc func translateAction(_ sender: Any?) {
        guard let doc = activeDoc else { return }
        if #available(macOS 26.0, *) {
            let tv = doc.textView
            let sel = tv.selectedRange()
            let s = tv.string as NSString
            let selLoc = min(sel.location, s.length)
            let selLen = min(sel.length, s.length - selLoc)
            let text = selLen > 0 ? s.substring(with: NSRange(location: selLoc, length: selLen)) : tv.string
            guard !text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty else {
                NSSound.beep()
                return
            }
            if translateHost == nil { translateHost = TranslationHost() }
            guard let host = translateHost as? TranslationHost else { return }
            host.install(in: window.contentView!)

            guard let source = TranslationHost.detectSource(text) else {
                NSSound.beep()
                return
            }
            guard let target = TranslationHost.preferredTarget(for: source) else {
                NSSound.beep()
                return
            }
            statusBar.translateButton.isEnabled = false
            host.translate(text: text, source: source, target: target) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.statusBar.translateButton.isEnabled = true
                    switch result {
                    case .success(let response):
                        let outcome = TranslationOutcome(
                            sourceName: TranslationHost.localized(name: response.sourceLanguage) ?? "auto",
                            targetName: TranslationHost.localized(name: response.targetLanguage) ?? "auto",
                            text: response.targetText
                        )
                        self.lastTranslation = (doc, NSRange(location: selLoc, length: selLen), outcome.text)
                        if self.translationSelfTest {
                            fputs("SPTEST-TRANSLATE: \(outcome.text)\n", stderr)
                            NSApp.terminate(nil)
                        }
                        self.showTranslatePanel(outcome: outcome)
                    case .failure(let error):
                        if self.translationSelfTest {
                            fputs("SPTEST-TRANSLATE-ERROR: \(error)\n", stderr)
                            NSApp.terminate(nil)
                        }
                        let alert = NSAlert()
                        alert.messageText = "翻译失败"
                        alert.informativeText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                        alert.beginSheetModal(for: self.window, completionHandler: nil)
                    }
                }
            }
        } else {
            let alert = NSAlert()
            alert.messageText = "本地翻译需要 macOS 26 或更高版本"
            alert.informativeText = "当前系统版本无法使用系统内置的本地翻译引擎。"
            alert.beginSheetModal(for: window, completionHandler: nil)
        }
    }

    private func showTranslatePanel(outcome: TranslationOutcome) {
        if translatePanel == nil {
            translatePanel = TranslatePanelWindow()
        }
        let replaceHandler: () -> Void = { [weak self] in
            guard let self, let last = self.lastTranslation,
                  self.documents.contains(last.doc),
                  let storage = last.doc.textView.textStorage else { return }
            let maxLen = storage.length
            let range = NSRange(location: min(last.range.location, maxLen),
                                length: min(last.range.length, maxLen - min(last.range.location, maxLen)))
            last.doc.textView.insertText(last.text, replacementRange: range)
            self.translatePanel?.orderOut(nil)
        }
        translatePanel?.show(outcome: outcome,
                             replaceTitle: lastTranslation?.range.length ?? 0 > 0 ? "替换所选" : "替换全文",
                             replaceHandler: replaceHandler)
    }

    // MARK: - Smart suggestions

    @objc func toggleSmartSuggest(_ sender: Any?) {
        Prefs.smartSuggest.toggle()
        if !Prefs.smartSuggest {
            for doc in documents { doc.textView.ghostText = nil }
        } else {
            SuggestionEngine.shared.save()
        }
        activeDoc?.textView.updateGhostSuggestion()
    }

    @objc func learnCurrentDocument(_ sender: Any?) {
        guard let doc = activeDoc, Prefs.smartSuggest else { NSSound.beep(); return }
        SuggestionEngine.shared.learn(doc.textView.string)
        let alert = NSAlert()
        alert.messageText = "已学习当前文档"
        alert.informativeText = SuggestionEngine.shared.statsSummary
        alert.beginSheetModal(for: window, completionHandler: nil)
    }

    // MARK: - App actions

    @objc func showAbout(_ sender: Any?) {
        NSApp.orderFrontStandardAboutPanel(options: [
            NSApplication.AboutPanelOptionKey.applicationName: "d2note",
            NSApplication.AboutPanelOptionKey.applicationVersion: "0.1",
            .credits: NSAttributedString(string: "本地智能笔记编辑器 🐰\n语法高亮 · 本地翻译 · 习惯推荐"),
        ])
    }

    private var settingsSheet: SettingsSheet?

    @objc func showSettings(_ sender: Any?) {
        let sheet = SettingsSheet()
        sheet.onChange = { [weak self] in
            self?.applyTheme()
            self?.applyPrefsToAll()
        }
        settingsSheet = sheet
        window.beginSheet(sheet, completionHandler: nil)
    }

    // MARK: - Undo/Redo forwarding (when editor not focused)

    @objc func undo(_ sender: Any?) {
        activeDoc?.textView.undoManager?.undo()
    }

    @objc func redo(_ sender: Any?) {
        activeDoc?.textView.undoManager?.redo()
    }

    // MARK: - Validation

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(toggleComment(_:)):
            guard let doc = activeDoc else { return false }
            return !doc.language.spec.lineComments.isEmpty || !doc.language.spec.blockComments.isEmpty
        case #selector(findNextAction(_:)), #selector(findPrevAction(_:)),
             #selector(saveDocument(_:)), #selector(saveDocumentAs(_:)),
             #selector(closeTabAction(_:)), #selector(goToLine(_:)),
             #selector(formatDocument(_:)), #selector(formatJSONAction(_:)),
             #selector(minifyJSONAction(_:)), #selector(formatXMLAction(_:)),
             #selector(trimTrailingAction(_:)), #selector(undo(_:)), #selector(redo(_:)):
            return activeDoc != nil
        case #selector(toggleWordWrap(_:)):
            menuItem.state = Prefs.wordWrap ? .on : .off
            return true
        case #selector(toggleLineNumbers(_:)):
            menuItem.state = Prefs.lineNumbers ? .on : .off
            return true
        case #selector(useDarkTheme(_:)):
            menuItem.state = Theme.current.isDark ? .on : .off
            return true
        case #selector(useLightTheme(_:)):
            menuItem.state = Theme.current.isDark ? .off : .on
            return true
        case #selector(toggleSmartSuggest(_:)):
            menuItem.state = Prefs.smartSuggest ? .on : .off
            return activeDoc != nil
        case #selector(learnCurrentDocument(_:)):
            return activeDoc != nil && Prefs.smartSuggest
        case #selector(translateAction(_:)):
            if #available(macOS 26.0, *) { return activeDoc != nil }
            return false
        default:
            return true
        }
    }
}
