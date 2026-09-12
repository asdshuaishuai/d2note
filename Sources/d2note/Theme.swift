import AppKit

enum TokenKind: Int, CaseIterable {
    case plain
    case keyword
    case string
    case number
    case comment
    case type
    case function
    case property
    case variable
    case key
    case punctuation
    case heading
    case interpolation
}

struct Theme {
    let name: String
    let isDark: Bool

    // Chrome
    let editorBackground: NSColor
    let editorText: NSColor
    let gutterBackground: NSColor
    let gutterText: NSColor
    let gutterActiveText: NSColor
    let currentLine: NSColor
    let selection: NSColor
    let bracketHighlight: NSColor
    let findUnderline: NSColor
    let tabBarBackground: NSColor
    let tabHoverBackground: NSColor
    let tabText: NSColor
    let tabActiveText: NSColor
    let tabSeparator: NSColor
    let accent: NSColor
    let statusBarBackground: NSColor
    let statusText: NSColor
    let insertPoint: NSColor

    let tokenColors: [TokenKind: NSColor]

    func color(for kind: TokenKind) -> NSColor {
        tokenColors[kind] ?? editorText
    }

    // MARK: - One Dark (dark)
    static let dark = Theme(
        name: "Dark",
        isDark: true,
        editorBackground: NSColor(red: 0.160, green: 0.176, blue: 0.204, alpha: 1),
        editorText: NSColor(red: 0.671, green: 0.698, blue: 0.745, alpha: 1),
        gutterBackground: NSColor(red: 0.137, green: 0.153, blue: 0.176, alpha: 1),
        gutterText: NSColor(red: 0.380, green: 0.400, blue: 0.443, alpha: 1),
        gutterActiveText: NSColor(red: 0.820, green: 0.847, blue: 0.890, alpha: 1),
        currentLine: NSColor(white: 1.0, alpha: 0.045),
        selection: NSColor(red: 0.239, green: 0.325, blue: 0.435, alpha: 0.55),
        bracketHighlight: NSColor(red: 0.239, green: 0.325, blue: 0.435, alpha: 0.45),
        findUnderline: NSColor(red: 0.918, green: 0.741, blue: 0.290, alpha: 1),
        tabBarBackground: NSColor(red: 0.125, green: 0.137, blue: 0.157, alpha: 1),
        tabHoverBackground: NSColor(white: 1.0, alpha: 0.05),
        tabText: NSColor(red: 0.550, green: 0.573, blue: 0.612, alpha: 1),
        tabActiveText: NSColor(red: 0.910, green: 0.925, blue: 0.949, alpha: 1),
        tabSeparator: NSColor(white: 1.0, alpha: 0.07),
        accent: NSColor(red: 0.380, green: 0.686, blue: 0.937, alpha: 1),
        statusBarBackground: NSColor(red: 0.125, green: 0.137, blue: 0.157, alpha: 1),
        statusText: NSColor(red: 0.588, green: 0.612, blue: 0.655, alpha: 1),
        insertPoint: NSColor(red: 0.710, green: 0.745, blue: 0.804, alpha: 1),
        tokenColors: [
            .keyword: NSColor(red: 0.776, green: 0.471, blue: 0.867, alpha: 1),
            .string: NSColor(red: 0.596, green: 0.765, blue: 0.475, alpha: 1),
            .number: NSColor(red: 0.820, green: 0.604, blue: 0.400, alpha: 1),
            .comment: NSColor(red: 0.408, green: 0.435, blue: 0.482, alpha: 1),
            .type: NSColor(red: 0.898, green: 0.753, blue: 0.482, alpha: 1),
            .function: NSColor(red: 0.380, green: 0.686, blue: 0.937, alpha: 1),
            .property: NSColor(red: 0.878, green: 0.424, blue: 0.459, alpha: 1),
            .variable: NSColor(red: 0.878, green: 0.424, blue: 0.459, alpha: 1),
            .key: NSColor(red: 0.878, green: 0.424, blue: 0.459, alpha: 1),
            .punctuation: NSColor(red: 0.580, green: 0.612, blue: 0.663, alpha: 1),
            .heading: NSColor(red: 0.380, green: 0.686, blue: 0.937, alpha: 1),
            .interpolation: NSColor(red: 0.560, green: 0.780, blue: 0.960, alpha: 1),
        ]
    )

    // MARK: - Xcode-like (light)
    static let light = Theme(
        name: "Light",
        isDark: false,
        editorBackground: NSColor(white: 1.0, alpha: 1),
        editorText: NSColor(red: 0.160, green: 0.180, blue: 0.216, alpha: 1),
        gutterBackground: NSColor(red: 0.973, green: 0.976, blue: 0.980, alpha: 1),
        gutterText: NSColor(red: 0.612, green: 0.643, blue: 0.694, alpha: 1),
        gutterActiveText: NSColor(red: 0.200, green: 0.230, blue: 0.280, alpha: 1),
        currentLine: NSColor(white: 0.0, alpha: 0.035),
        selection: NSColor(red: 0.290, green: 0.510, blue: 0.850, alpha: 0.25),
        bracketHighlight: NSColor(red: 0.290, green: 0.510, blue: 0.850, alpha: 0.18),
        findUnderline: NSColor(red: 0.850, green: 0.620, blue: 0.100, alpha: 1),
        tabBarBackground: NSColor(red: 0.949, green: 0.953, blue: 0.960, alpha: 1),
        tabHoverBackground: NSColor(white: 0.0, alpha: 0.045),
        tabText: NSColor(red: 0.380, green: 0.410, blue: 0.460, alpha: 1),
        tabActiveText: NSColor(red: 0.120, green: 0.140, blue: 0.180, alpha: 1),
        tabSeparator: NSColor(white: 0.0, alpha: 0.10),
        accent: NSColor(red: 0.190, green: 0.450, blue: 0.850, alpha: 1),
        statusBarBackground: NSColor(red: 0.949, green: 0.953, blue: 0.960, alpha: 1),
        statusText: NSColor(red: 0.400, green: 0.430, blue: 0.480, alpha: 1),
        insertPoint: NSColor(red: 0.100, green: 0.120, blue: 0.160, alpha: 1),
        tokenColors: [
            .keyword: NSColor(red: 0.651, green: 0.239, blue: 0.643, alpha: 1),
            .string: NSColor(red: 0.776, green: 0.286, blue: 0.184, alpha: 1),
            .number: NSColor(red: 0.141, green: 0.161, blue: 0.847, alpha: 1),
            .comment: NSColor(red: 0.569, green: 0.608, blue: 0.667, alpha: 1),
            .type: NSColor(red: 0.290, green: 0.506, blue: 0.529, alpha: 1),
            .function: NSColor(red: 0.235, green: 0.427, blue: 0.757, alpha: 1),
            .property: NSColor(red: 0.855, green: 0.290, blue: 0.318, alpha: 1),
            .variable: NSColor(red: 0.855, green: 0.290, blue: 0.318, alpha: 1),
            .key: NSColor(red: 0.855, green: 0.290, blue: 0.318, alpha: 1),
            .punctuation: NSColor(red: 0.360, green: 0.390, blue: 0.440, alpha: 1),
            .heading: NSColor(red: 0.235, green: 0.427, blue: 0.757, alpha: 1),
            .interpolation: NSColor(red: 0.180, green: 0.480, blue: 0.820, alpha: 1),
        ]
    )

    static var current: Theme {
        get {
            let name = UserDefaults.standard.string(forKey: "sp.theme") ?? "Dark"
            return name == "Light" ? .light : .dark
        }
        set {
            UserDefaults.standard.set(newValue.name, forKey: "sp.theme")
        }
    }
}

enum Prefs {
    static var fontSize: Int {
        get { UserDefaults.standard.object(forKey: "sp.fontSize") as? Int ?? 13 }
        set { UserDefaults.standard.set(newValue, forKey: "sp.fontSize") }
    }
    static var tabWidth: Int {
        get { UserDefaults.standard.object(forKey: "sp.tabWidth") as? Int ?? 4 }
        set { UserDefaults.standard.set(newValue, forKey: "sp.tabWidth") }
    }
    static var wordWrap: Bool {
        get { UserDefaults.standard.object(forKey: "sp.wordWrap") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "sp.wordWrap") }
    }
    static var lineNumbers: Bool {
        get { UserDefaults.standard.object(forKey: "sp.lineNumbers") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "sp.lineNumbers") }
    }
    static var autoClosePairs: Bool {
        get { UserDefaults.standard.object(forKey: "sp.autoClose") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "sp.autoClose") }
    }
    /// Smart habit suggestions — opt-in, default off.
    static var smartSuggest: Bool {
        get { UserDefaults.standard.object(forKey: "sp.smartSuggest") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "sp.smartSuggest") }
    }
    /// Draft autosave — on by default.
    static var autoSaveDrafts: Bool {
        get { UserDefaults.standard.object(forKey: "sp.autoSaveDrafts") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "sp.autoSaveDrafts") }
    }
    static var firstRunDone: Bool {
        get { UserDefaults.standard.bool(forKey: "sp.firstRunDone") }
        set { UserDefaults.standard.set(newValue, forKey: "sp.firstRunDone") }
    }
}
