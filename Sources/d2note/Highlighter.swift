import AppKit

// MARK: - Language specification

struct StringRule {
    let open: String
    let close: String
    let escape: Bool
    let multiline: Bool
}

struct LangSpec {
    var lineComments: [String] = []
    var lineCommentNeedsSpaceBefore = false
    var blockComments: [(String, String)] = []
    var stringRules: [StringRule] = []
    var charLiteral = false
    var keywords: Set<String> = []
    var caseInsensitiveKeywords = false
    var typeWords: Set<String> = []
    var uppercaseIsType = false
    var preprocessor = false
    var defKeyword: String? = nil
    var classKeyword: String? = nil
}

extension SourceLanguage {
    var spec: LangSpec {
        switch self {
        case .swift:
            return LangSpec(
                stringRules: [
                    StringRule(open: "\"\"\"", close: "\"\"\"", escape: true, multiline: true),
                    StringRule(open: "\"", close: "\"", escape: true, multiline: false),
                ],
                keywords: [
                    "as", "associatedtype", "async", "await", "break", "case", "catch", "class", "continue",
                    "default", "defer", "deinit", "do", "else", "enum", "extension", "fallthrough", "false",
                    "fileprivate", "for", "func", "get", "guard", "if", "import", "in", "init", "inout",
                    "internal", "is", "let", "nil", "open", "operator", "private", "protocol", "public",
                    "repeat", "rethrows", "return", "self", "Self", "set", "some", "static", "struct",
                    "subscript", "super", "switch", "throw", "throws", "true", "try", "typealias", "var",
                    "where", "while", "willSet", "didSet", "indirect", "lazy", "mutating", "nonmutating",
                    "optional", "required", "unsafe", "convenience", "dynamic", "final", "infix", "override",
                ],
                typeWords: ["Int", "Double", "Float", "Bool", "String", "Array", "Dictionary", "Set", "Void",
                            "Any", "AnyObject", "Optional", "Result", "Error", "Date", "Data", "URL", "Never"],
                uppercaseIsType: true,
                defKeyword: "func",
                classKeyword: "class"
            )
        case .python:
            return LangSpec(
                lineComments: ["#"],
                stringRules: [
                    StringRule(open: "\"\"\"", close: "\"\"\"", escape: true, multiline: true),
                    StringRule(open: "'''", close: "'''", escape: true, multiline: true),
                    StringRule(open: "\"", close: "\"", escape: true, multiline: false),
                    StringRule(open: "'", close: "'", escape: true, multiline: false),
                ],
                keywords: [
                    "and", "as", "assert", "async", "await", "break", "class", "continue", "def", "del",
                    "elif", "else", "except", "False", "finally", "for", "from", "global", "if", "import",
                    "in", "is", "lambda", "None", "nonlocal", "not", "or", "pass", "raise", "return",
                    "True", "try", "while", "with", "yield", "match", "case",
                ],
                typeWords: ["int", "float", "str", "bool", "list", "dict", "set", "tuple", "bytes", "object"],
                uppercaseIsType: true,
                defKeyword: "def",
                classKeyword: "class"
            )
        case .javascript, .typescript:
            var kw: Set<String> = [
                "async", "await", "break", "case", "catch", "class", "const", "continue", "debugger",
                "default", "delete", "do", "else", "enum", "export", "extends", "false", "finally", "for",
                "function", "if", "implements", "import", "in", "instanceof", "interface", "let", "new",
                "null", "of", "private", "protected", "public", "readonly", "return", "satisfies", "static",
                "super", "switch", "this", "throw", "true", "try", "type", "typeof", "undefined", "var",
                "void", "while", "with", "yield", "abstract", "declare", "keyof", "infer", "as", "namespace",
            ]
            var types: Set<String> = ["string", "number", "boolean", "any", "unknown", "never", "object", "symbol", "bigint"]
            if self == .typescript {
                kw.formUnion(["string", "number", "boolean", "any", "unknown", "never"])
            }
            return LangSpec(
                lineComments: ["//"],
                blockComments: [("/*", "*/")],
                stringRules: [
                    StringRule(open: "`", close: "`", escape: true, multiline: true),
                    StringRule(open: "\"", close: "\"", escape: true, multiline: false),
                    StringRule(open: "'", close: "'", escape: true, multiline: false),
                ],
                keywords: kw,
                typeWords: types,
                uppercaseIsType: true,
                defKeyword: "function",
                classKeyword: "class"
            )
        case .c:
            return LangSpec(
                lineComments: ["//"],
                blockComments: [("/*", "*/")],
                stringRules: [
                    StringRule(open: "\"", close: "\"", escape: true, multiline: false),
                ],
                charLiteral: true,
                keywords: [
                    "auto", "break", "case", "char", "const", "continue", "default", "do", "double", "else",
                    "enum", "extern", "float", "for", "goto", "if", "inline", "int", "long", "register",
                    "restrict", "return", "short", "signed", "sizeof", "static", "struct", "switch",
                    "typedef", "union", "unsigned", "void", "volatile", "while", "NULL", "bool", "true", "false",
                ],
                typeWords: ["size_t", "uint8_t", "uint16_t", "uint32_t", "uint64_t", "int8_t", "int16_t",
                            "int32_t", "int64_t", "FILE"],
                preprocessor: true,
                defKeyword: nil
            )
        case .cpp:
            return LangSpec(
                lineComments: ["//"],
                blockComments: [("/*", "*/")],
                stringRules: [
                    StringRule(open: "\"", close: "\"", escape: true, multiline: false),
                ],
                charLiteral: true,
                keywords: [
                    "alignas", "alignof", "and", "auto", "bool", "break", "case", "catch", "char", "class",
                    "const", "constexpr", "const_cast", "continue", "decltype", "default", "delete", "do",
                    "double", "dynamic_cast", "else", "enum", "explicit", "export", "extern", "false",
                    "float", "for", "friend", "goto", "if", "inline", "int", "long", "mutable", "namespace",
                    "new", "noexcept", "nullptr", "operator", "private", "protected", "public", "register",
                    "reinterpret_cast", "return", "short", "signed", "sizeof", "static", "static_cast",
                    "struct", "switch", "template", "this", "throw", "true", "try", "typedef", "typeid",
                    "typename", "union", "unsigned", "using", "virtual", "void", "volatile", "while",
                    "override", "final",
                ],
                typeWords: ["std", "string", "vector", "map", "unordered_map", "set", "shared_ptr", "unique_ptr",
                            "size_t", "cout", "cin", "endl", "optional", "variant", "span"],
                preprocessor: true,
                defKeyword: nil
            )
        case .csharp:
            return LangSpec(
                lineComments: ["//"],
                blockComments: [("/*", "*/")],
                stringRules: [
                    StringRule(open: "\"", close: "\"", escape: true, multiline: false),
                    StringRule(open: "\"\"\"", close: "\"\"\"", escape: true, multiline: true),
                ],
                charLiteral: true,
                keywords: [
                    "abstract", "as", "async", "await", "base", "bool", "break", "byte", "case", "catch",
                    "char", "checked", "class", "const", "continue", "decimal", "default", "delegate", "do",
                    "double", "else", "enum", "event", "explicit", "extern", "false", "finally", "fixed",
                    "float", "for", "foreach", "get", "goto", "if", "implicit", "in", "int", "interface",
                    "internal", "is", "lock", "long", "namespace", "new", "null", "object", "operator", "out",
                    "override", "params", "private", "protected", "public", "readonly", "ref", "return",
                    "sbyte", "sealed", "set", "short", "sizeof", "stackalloc", "static", "string", "struct",
                    "switch", "this", "throw", "true", "try", "typeof", "uint", "ulong", "unchecked",
                    "unsafe", "ushort", "using", "var", "virtual", "void", "volatile", "while", "record",
                    "init", "when", "where", "yield",
                ],
                uppercaseIsType: true,
                preprocessor: true,
                defKeyword: nil
            )
        case .java:
            return LangSpec(
                lineComments: ["//"],
                blockComments: [("/*", "*/")],
                stringRules: [
                    StringRule(open: "\"\"\"", close: "\"\"\"", escape: true, multiline: true),
                    StringRule(open: "\"", close: "\"", escape: true, multiline: false),
                ],
                charLiteral: true,
                keywords: [
                    "abstract", "assert", "boolean", "break", "byte", "case", "catch", "char", "class",
                    "const", "continue", "default", "do", "double", "else", "enum", "extends", "final",
                    "finally", "float", "for", "goto", "if", "implements", "import", "instanceof", "int",
                    "interface", "long", "native", "new", "package", "private", "protected", "public",
                    "return", "short", "static", "strictfp", "super", "switch", "synchronized", "this",
                    "throw", "throws", "transient", "try", "void", "volatile", "while", "var", "true",
                    "false", "null", "record", "sealed", "yield",
                ],
                typeWords: ["String", "Integer", "Long", "Boolean", "Double", "Float", "Object", "List",
                            "Map", "Set", "Optional", "Stream"],
                uppercaseIsType: true,
                defKeyword: nil
            )
        case .go:
            return LangSpec(
                lineComments: ["//"],
                blockComments: [("/*", "*/")],
                stringRules: [
                    StringRule(open: "`", close: "`", escape: false, multiline: true),
                    StringRule(open: "\"", close: "\"", escape: true, multiline: false),
                ],
                charLiteral: true,
                keywords: [
                    "break", "case", "chan", "const", "continue", "default", "defer", "else",
                    "fallthrough", "for", "func", "go", "goto", "if", "import", "interface", "map",
                    "package", "range", "return", "select", "struct", "switch", "type", "var", "nil",
                    "true", "false", "iota",
                ],
                typeWords: ["string", "int", "int8", "int16", "int32", "int64", "uint", "uint8", "uint16",
                            "uint32", "uint64", "float32", "float64", "bool", "byte", "rune", "error",
                            "any", "complex64", "complex128", "uintptr"],
                uppercaseIsType: true,
                defKeyword: "func",
                classKeyword: "type"
            )
        case .rust:
            return LangSpec(
                lineComments: ["//"],
                blockComments: [("/*", "*/")],
                stringRules: [
                    StringRule(open: "\"", close: "\"", escape: true, multiline: true),
                ],
                charLiteral: false,
                keywords: [
                    "as", "async", "await", "break", "const", "continue", "crate", "dyn", "else", "enum",
                    "extern", "false", "fn", "for", "if", "impl", "in", "let", "loop", "match", "mod",
                    "move", "mut", "pub", "ref", "return", "self", "Self", "static", "struct", "super",
                    "trait", "true", "type", "unsafe", "use", "where", "while", "union",
                ],
                typeWords: ["i8", "i16", "i32", "i64", "i128", "isize", "u8", "u16", "u32", "u64", "u128",
                            "usize", "f32", "f64", "bool", "char", "str", "String", "Vec", "Option",
                            "Result", "Box", "Rc", "Arc"],
                uppercaseIsType: true,
                defKeyword: "fn",
                classKeyword: "struct"
            )
        case .ruby:
            return LangSpec(
                lineComments: ["#"],
                stringRules: [
                    StringRule(open: "\"", close: "\"", escape: true, multiline: false),
                    StringRule(open: "'", close: "'", escape: false, multiline: false),
                ],
                keywords: [
                    "alias", "and", "begin", "break", "case", "class", "def", "defined?", "do", "else",
                    "elsif", "end", "ensure", "false", "for", "if", "in", "module", "next", "nil", "not",
                    "or", "redo", "rescue", "retry", "return", "self", "super", "then", "true", "undef",
                    "unless", "until", "when", "while", "yield", "attr_accessor", "attr_reader", "attr_writer",
                    "require", "require_relative", "puts", "p", "raise", "new",
                ],
                uppercaseIsType: true,
                defKeyword: "def",
                classKeyword: "class"
            )
        case .php:
            return LangSpec(
                lineComments: ["//", "#"],
                blockComments: [("/*", "*/")],
                stringRules: [
                    StringRule(open: "\"", close: "\"", escape: true, multiline: false),
                    StringRule(open: "'", close: "'", escape: false, multiline: false),
                ],
                keywords: [
                    "abstract", "and", "array", "as", "break", "callable", "case", "catch", "class",
                    "clone", "const", "continue", "declare", "default", "do", "echo", "else", "elseif",
                    "empty", "enddeclare", "endfor", "endforeach", "endif", "endswitch", "endwhile",
                    "enum", "extends", "final", "finally", "fn", "for", "foreach", "function", "global",
                    "goto", "if", "implements", "include", "include_once", "instanceof", "insteadof",
                    "interface", "isset", "list", "match", "namespace", "new", "or", "print", "private",
                    "protected", "public", "readonly", "require", "require_once", "return", "static",
                    "switch", "throw", "trait", "try", "unset", "use", "var", "while", "xor", "yield",
                    "true", "false", "null", "self", "parent",
                ],
                uppercaseIsType: true,
                defKeyword: "function",
                classKeyword: "class"
            )
        case .json:
            return LangSpec(
                lineComments: ["//"],
                blockComments: [("/*", "*/")],
                stringRules: [
                    StringRule(open: "\"", close: "\"", escape: true, multiline: false),
                ],
                keywords: ["true", "false", "null"]
            )
        case .yaml:
            return LangSpec(
                lineComments: ["#"],
                lineCommentNeedsSpaceBefore: true,
                stringRules: [
                    StringRule(open: "\"", close: "\"", escape: true, multiline: false),
                    StringRule(open: "'", close: "'", escape: false, multiline: false),
                ],
                keywords: ["true", "false", "null", "yes", "no", "on", "off"]
            )
        case .shell:
            return LangSpec(
                lineComments: ["#"],
                stringRules: [
                    StringRule(open: "'", close: "'", escape: false, multiline: false),
                    StringRule(open: "\"", close: "\"", escape: true, multiline: false),
                    StringRule(open: "`", close: "`", escape: false, multiline: false),
                ],
                keywords: [
                    "if", "then", "else", "elif", "fi", "for", "while", "until", "do", "done", "case",
                    "esac", "function", "in", "return", "exit", "local", "export", "readonly", "shift",
                    "break", "continue", "source", "alias", "set", "unset", "trap", "eval", "exec",
                    "echo", "printf", "read", "cd", "pwd", "test", "true", "false",
                ]
            )
        case .sql:
            return LangSpec(
                lineComments: ["--"],
                blockComments: [("/*", "*/")],
                stringRules: [
                    StringRule(open: "'", close: "'", escape: false, multiline: false),
                ],
                keywords: [
                    "select", "from", "where", "insert", "into", "values", "update", "set", "delete",
                    "create", "table", "database", "index", "view", "drop", "alter", "add", "column",
                    "primary", "key", "foreign", "references", "join", "inner", "left", "right", "full",
                    "outer", "on", "group", "by", "order", "having", "limit", "offset", "as", "and",
                    "or", "not", "null", "is", "in", "between", "like", "exists", "case", "when", "then",
                    "else", "end", "distinct", "union", "all", "asc", "desc", "count", "sum", "avg",
                    "min", "max", "constraint", "default", "unique", "check", "begin", "commit",
                    "rollback", "transaction", "if", "with", "returning", "window", "partition", "over",
                    "row_number", "rank", "true", "false", "int", "integer", "varchar", "char", "text",
                    "boolean", "date", "timestamp", "decimal", "numeric", "float", "double", "real",
                    "blob", "serial", "auto_increment", "cascade",
                ],
                caseInsensitiveKeywords: true
            )
        case .plain:
            return LangSpec()
        case .markdown, .html, .xml, .css:
            return LangSpec()
        }
    }

    var usesBraceIndent: Bool {
        switch self {
        case .swift, .javascript, .typescript, .c, .cpp, .csharp, .java, .go, .rust, .css, .json, .php:
            return true
        default:
            return false
        }
    }
}

// MARK: - Tokenizer

enum Tokenizer {

    static func tokenize(_ text: String, language: SourceLanguage) -> [(NSRange, TokenKind)] {
        switch language {
        case .markdown: return markdownTokens(text)
        case .html, .xml: return markupTokens(text, isHTML: language == .html)
        case .css: return cssTokens(text)
        default: return codeTokens(text, language: language)
        }
    }

    // MARK: Generic code tokenizer

    static func codeTokens(_ text: String, language: SourceLanguage) -> [(NSRange, TokenKind)] {
        let spec = language.spec
        let kwSet = spec.caseInsensitiveKeywords ? Set(spec.keywords.map { $0.lowercased() }) : spec.keywords
        let u = Array(text.utf16)
        let n = u.count
        var out: [(NSRange, TokenKind)] = []
        out.reserveCapacity(n / 10 + 16)

        var i = 0
        var atLineStart = true          // only whitespace/newlines since line start
        var prevIsSpaceOrStart = true   // last significant char was whitespace or none
        var expectDefName = false       // just saw `def` / `func` / `fn`
        var expectTypeName = false      // just saw `class` / `struct`

        func eq(_ pattern: String, at pos: Int) -> Bool {
            let p = Array(pattern.utf16)
            if pos + p.count > n { return false }
            for k in 0..<p.count where u[pos + k] != p[k] { return false }
            return true
        }
        func push(_ start: Int, _ end: Int, _ kind: TokenKind) {
            if end > start { out.append((NSRange(location: start, length: end - start), kind)) }
        }
        func isIdentStart(_ c: unichar) -> Bool {
            if (c >= 97 && c <= 122) || (c >= 65 && c <= 90) || c == 0x5F || c == 0x24 { return true }
            if c >= 0x80 { return true } // treat non-ascii as identifier chars (safe for code)
            return false
        }
        func isIdentPart(_ c: unichar) -> Bool {
            isIdentStart(c) || (c >= 48 && c <= 57)
        }
        func isDigit(_ c: unichar) -> Bool { c >= 48 && c <= 57 }

        while i < n {
            let c = u[i]

            if c == 0x0D { i += 1; continue }
            if c == 0x0A { atLineStart = true; prevIsSpaceOrStart = true; expectDefName = false; i += 1; continue }
            if c == 0x20 || c == 0x09 { i += 1; continue }

            // Block comments
            var matchedBlock = false
            for (open, close) in spec.blockComments where eq(open, at: i) {
                let olen = open.utf16.count
                var j = i + olen
                while j < n && !eq(close, at: j) { j += 1 }
                let end = j < n ? j + close.utf16.count : j
                push(i, end, .comment)
                i = end
                matchedBlock = true
                break
            }
            if matchedBlock { prevIsSpaceOrStart = false; continue }

            // Line comments
            var lcOK = false
            for lc in spec.lineComments {
                if eq(lc, at: i), !spec.lineCommentNeedsSpaceBefore || prevIsSpaceOrStart {
                    var j = i
                    while j < n && u[j] != 0x0A { j += 1 }
                    push(i, j, .comment)
                    i = j
                    lcOK = true
                    break
                }
            }
            if lcOK { prevIsSpaceOrStart = false; continue }

            // Strings
            var matchedString = false
            for rule in spec.stringRules where eq(rule.open, at: i) {
                i = scanString(u, from: i, rule: rule, spec: spec, language: language, push: push)
                matchedString = true
                break
            }
            if matchedString { atLineStart = false; prevIsSpaceOrStart = false; expectDefName = false; continue }

            // Preprocessor directives (# at line start for C family, anywhere for Swift)
            if c == 0x23, (spec.preprocessor && atLineStart) || language == .swift,
               !spec.lineComments.contains("#") {
                var j = i + 1
                if language == .swift {
                    while j < n && isIdentPart(u[j]) { j += 1 }
                    push(i, j, .keyword)
                } else {
                    while j < n && u[j] != 0x0A { j += 1 }
                    push(i, j, .keyword)
                }
                i = j
                atLineStart = false
                prevIsSpaceOrStart = false
                continue
            }

            // Shell / general $variable
            if c == 0x24, language == .shell, i + 1 < n {
                var j = i + 1
                if j < n && u[j] == 0x7B { // ${
                    j += 1
                    while j < n && u[j] != 0x7D { j += 1 }
                    if j < n { j += 1 }
                } else {
                    while j < n && isIdentPart(u[j]) { j += 1 }
                }
                push(i, j, .variable)
                i = j
                atLineStart = false
                prevIsSpaceOrStart = false
                continue
            }

            // Decorators / attributes @Word
            if c == 0x40, i + 1 < n, isIdentStart(u[i + 1]) {
                var j = i + 1
                while j < n && isIdentPart(u[j]) { j += 1 }
                push(i, j, .type)
                i = j
                atLineStart = false
                prevIsSpaceOrStart = false
                continue
            }

            // YAML keys and list markers
            if language == .yaml {
                if c == 0x2D && atLineStart, i + 1 < n, u[i + 1] == 0x20 { // "- "
                    push(i, i + 1, .punctuation)
                    i += 1
                    atLineStart = false
                    prevIsSpaceOrStart = false
                    continue
                }
                if isIdentStart(c) || c == 0x22 || c == 0x27 {
                    // scan potential key
                    var j = i
                    while j < n && isIdentPart(u[j]) { j += 1 }
                    if j > i && j < n {
                        var k = j
                        while k < n && (u[k] == 0x20 || u[k] == 0x09) { k += 1 }
                        if k < n && u[k] == 0x3A && (k + 1 >= n || u[k + 1] == 0x20 || u[k + 1] == 0x0A || u[k + 1] == 0x0D) {
                            push(i, j, .key)
                            push(j, k + 1, .punctuation)
                            i = k + 1
                            atLineStart = false
                            prevIsSpaceOrStart = false
                            continue
                        }
                    }
                }
            }

            // Numbers
            if isDigit(c) || (c == 0x2E && i + 1 < n && isDigit(u[i + 1])) {
                var j = i
                if c == 0x30 && j + 1 < n && (u[j + 1] == 0x78 || u[j + 1] == 0x58 || u[j + 1] == 0x62 || u[j + 1] == 0x42 || u[j + 1] == 0x6F || u[j + 1] == 0x4F) {
                    j += 2
                    while j < n && (isIdentPart(u[j])) { j += 1 }
                } else {
                    while j < n && (isDigit(u[j]) || u[j] == 0x5F) { j += 1 }
                    if j < n && u[j] == 0x2E && j + 1 < n && isDigit(u[j + 1]) {
                        j += 1
                        while j < n && (isDigit(u[j]) || u[j] == 0x5F) { j += 1 }
                    }
                    if j < n && (u[j] == 0x65 || u[j] == 0x45) {
                        var k = j + 1
                        if k < n && (u[k] == 0x2B || u[k] == 0x2D) { k += 1 }
                        if k < n && isDigit(u[k]) {
                            j = k
                            while j < n && isDigit(u[j]) { j += 1 }
                        }
                    }
                    // numeric suffixes like 100f, 10UL, 0xFFu
                    while j < n && isIdentPart(u[j]) && u[j] != 0x5F && isLetterASCII(u[j]) { j += 1 }
                }
                push(i, j, .number)
                i = j
                atLineStart = false
                prevIsSpaceOrStart = false
                expectDefName = false
                continue
            }

            // Identifiers / keywords
            if isIdentStart(c) {
                var j = i
                while j < n && isIdentPart(u[j]) { j += 1 }
                let word = String(decoding: u[i..<j], as: UTF16.self)
                let lookup = spec.caseInsensitiveKeywords ? word.lowercased() : word
                var kind: TokenKind? = nil
                if kwSet.contains(lookup) {
                    kind = .keyword
                    if word == spec.defKeyword { expectDefName = true }
                    else if word == spec.classKeyword { expectTypeName = true }
                    else { expectDefName = false; expectTypeName = false }
                } else if spec.typeWords.contains(word) {
                    kind = .type
                    expectDefName = false
                    expectTypeName = false
                } else if expectDefName {
                    kind = .function
                    expectDefName = false
                } else if expectTypeName {
                    kind = .type
                    expectTypeName = false
                } else if spec.uppercaseIsType && firstIsUppercase(word) {
                    kind = .type
                } else {
                    // function call: identifier followed by '('
                    var k = j
                    while k < n && (u[k] == 0x20 || u[k] == 0x09) { k += 1 }
                    if k < n && u[k] == 0x28 { kind = .function }
                }
                push(i, j, kind ?? .plain)
                i = j
                atLineStart = false
                prevIsSpaceOrStart = false
                continue
            }

            // Rust lifetimes: 'a (not a char literal)
            if language == .rust && c == 0x27 {
                var j = i + 1
                while j < n && isIdentPart(u[j]) { j += 1 }
                push(i, j, .keyword)
                i = j
                continue
            }

            // Characters: C-like char literals 'x'
            if spec.charLiteral && c == 0x27 {
                var j = i + 1
                if j < n && u[j] == 0x5C { j += 2 }
                if j < n { j += 1 }
                if j < n && u[j] == 0x27 { j += 1 }
                push(i, j, .string)
                i = j
                atLineStart = false
                prevIsSpaceOrStart = false
                continue
            }

            i += 1
            atLineStart = false
            prevIsSpaceOrStart = false
            expectDefName = false
        }
        return out
    }

    private static func isLetterASCII(_ c: unichar) -> Bool {
        (c >= 65 && c <= 90) || (c >= 97 && c <= 122)
    }

    private static func firstIsUppercase(_ word: String) -> Bool {
        guard let f = word.utf16.first else { return false }
        return f >= 65 && f <= 90
    }

    /// Scan a string starting at `start` (which matches rule.open). Returns end index.
    /// Emits the string token; handles escapes, Swift interpolation, shell $vars, JSON keys.
    private static func scanString(
        _ u: [unichar], from start: Int, rule: StringRule, spec: LangSpec,
        language: SourceLanguage, push: (Int, Int, TokenKind) -> Void
    ) -> Int {
        let n = u.count
        let olen = rule.open.utf16.count
        let clen = rule.close.utf16.count
        var i = start + olen
        var segStart = start

        func eq(_ pattern: String, at pos: Int) -> Bool {
            let p = Array(pattern.utf16)
            if pos + p.count > n { return false }
            for k in 0..<p.count where u[pos + k] != p[k] { return false }
            return true
        }
        func isIdentPart(_ c: unichar) -> Bool {
            let a = c >= 97 && c <= 122, b = c >= 65 && c <= 90
            return a || b || c == 0x5F || c == 0x24 || (c >= 48 && c <= 57) || c >= 0x80
        }

        while i < n {
            if rule.escape, u[i] == 0x5C {
                // Swift interpolation \( ... )
                if language == .swift, i + 1 < n, u[i + 1] == 0x28 {
                    if i > segStart { push(segStart, i, .string) }
                    var depth = 1
                    var j = i + 2
                    while j < n && depth > 0 {
                        if u[j] == 0x28 { depth += 1 }
                        else if u[j] == 0x29 { depth -= 1 }
                        if depth == 0 { break }
                        j += 1
                    }
                    let end = min(j + 1, n)
                    push(i, end, .interpolation)
                    i = end
                    segStart = i
                    continue
                }
                i += 2
                continue
            }
            // Shell $variables inside double quotes
            if language == .shell, rule.open == "\"", u[i] == 0x24, i + 1 < n {
                let next = u[i + 1]
                if isIdentPart(next) || next == 0x7B {
                    if i > segStart { push(segStart, i, .string) }
                    var j = i + 1
                    if next == 0x7B {
                        j += 1
                        while j < n && u[j] != 0x7D { j += 1 }
                        if j < n { j += 1 }
                    } else {
                        while j < n && isIdentPart(u[j]) { j += 1 }
                    }
                    push(i, j, .variable)
                    i = j
                    segStart = i
                    continue
                }
            }
            if eq(rule.close, at: i) {
                let end = i + clen
                push(segStart, end, stringKind(for: rule, at: end, u: u, n: n))
                return end
            }
            if u[i] == 0x0A && !rule.multiline {
                push(segStart, i, stringKind(for: rule, at: i, u: u, n: n))
                return i
            }
            i += 1
        }
        push(segStart, n, .string)
        return n
    }

    /// JSON keys (string followed by `:`) get a distinct color.
    private static func stringKind(for rule: StringRule, at end: Int, u: [unichar], n: Int) -> TokenKind {
        var k = end
        while k < n && (u[k] == 0x20 || u[k] == 0x09 || u[k] == 0x0A || u[k] == 0x0D) { k += 1 }
        if k < n && u[k] == 0x3A { return .key }
        return .string
    }

    // MARK: CSS

    static func cssTokens(_ text: String) -> [(NSRange, TokenKind)] {
        var out: [(NSRange, TokenKind)] = []
        let u = Array(text.utf16)
        let n = u.count
        var i = 0
        var braceDepth = 0

        func eq(_ pattern: String, at pos: Int) -> Bool {
            let p = Array(pattern.utf16)
            if pos + p.count > n { return false }
            for k in 0..<p.count where u[pos + k] != p[k] { return false }
            return true
        }
        func push(_ start: Int, _ end: Int, _ kind: TokenKind) {
            if end > start { out.append((NSRange(location: start, length: end - start), kind)) }
        }
        func isIdentStart(_ c: unichar) -> Bool {
            (c >= 97 && c <= 122) || (c >= 65 && c <= 90) || c == 0x5F || c == 0x2D || c >= 0x80
        }
        func isIdentPart(_ c: unichar) -> Bool { isIdentStart(c) || (c >= 48 && c <= 57) }
        func isDigit(_ c: unichar) -> Bool { c >= 48 && c <= 57 }

        while i < n {
            let c = u[i]
            if c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D { i += 1; continue }
            if eq("/*", at: i) {
                var j = i + 2
                while j < n && !eq("*/", at: j) { j += 1 }
                let end = j < n ? j + 2 : j
                push(i, end, .comment)
                i = end
                continue
            }
            if c == 0x7B { braceDepth += 1; push(i, i + 1, .punctuation); i += 1; continue }
            if c == 0x7D { braceDepth = max(0, braceDepth - 1); push(i, i + 1, .punctuation); i += 1; continue }
            if c == 0x40 { // @media etc
                var j = i + 1
                while j < n && isIdentPart(u[j]) { j += 1 }
                push(i, j, .keyword)
                i = j
                continue
            }
            if c == 0x22 || c == 0x27 {
                let quote = c
                var j = i + 1
                while j < n && u[j] != quote && u[j] != 0x0A {
                    if u[j] == 0x5C { j += 1 }
                    j += 1
                }
                let end = min(j + 1, n)
                push(i, end, .string)
                i = end
                continue
            }
            if c == 0x23 { // hex color or #id
                var j = i + 1
                var hexCount = 0
                while j < n && isHex(u[j]) { hexCount += 1; j += 1 }
                if hexCount == 3 || hexCount == 4 || hexCount == 6 || hexCount == 8 {
                    push(i, j, .number)
                } else {
                    while j < n && isIdentPart(u[j]) { j += 1 }
                    push(i, j, .type)
                }
                i = j
                continue
            }
            if c == 0x2E { // .class
                var j = i + 1
                while j < n && isIdentPart(u[j]) { j += 1 }
                push(i, j, .type)
                i = j
                continue
            }
            if isDigit(c) || (c == 0x2E && i + 1 < n && isDigit(u[i + 1])) ||
               (c == 0x2D && i + 1 < n && isDigit(u[i + 1])) {
                var j = i
                if u[j] == 0x2D { j += 1 }
                while j < n && (isDigit(u[j]) || u[j] == 0x2E) { j += 1 }
                while j < n && (isIdentPart(u[j]) || u[j] == 0x25) { j += 1 } // units px, %, rem...
                push(i, j, .number)
                i = j
                continue
            }
            if isIdentStart(c) {
                var j = i
                while j < n && isIdentPart(u[j]) { j += 1 }
                var k = j
                while k < n && (u[k] == 0x20 || u[k] == 0x09) { k += 1 }
                if k < n && u[k] == 0x3A && braceDepth > 0 && (k + 1 >= n || u[k + 1] != 0x3A) {
                    push(i, j, .property)
                } else if i < n && u[i] == 0x2D && j > i + 1 {
                    push(i, j, .function) // pseudo like -webkit
                } else {
                    push(i, j, .plain)
                }
                i = j
                continue
            }
            i += 1
        }
        return out
    }

    private static func isHex(_ c: unichar) -> Bool {
        (c >= 48 && c <= 57) || (c >= 65 && c <= 70) || (c >= 97 && c <= 102)
    }

    // MARK: HTML / XML

    static func markupTokens(_ text: String, isHTML: Bool) -> [(NSRange, TokenKind)] {
        var out: [(NSRange, TokenKind)] = []
        let u = Array(text.utf16)
        let n = u.count
        var i = 0
        var inTag = false

        func eq(_ pattern: String, at pos: Int) -> Bool {
            let p = Array(pattern.utf16)
            if pos + p.count > n { return false }
            for k in 0..<p.count where u[pos + k] != p[k] { return false }
            return true
        }
        func push(_ start: Int, _ end: Int, _ kind: TokenKind) {
            if end > start { out.append((NSRange(location: start, length: end - start), kind)) }
        }
        func isIdentStart(_ c: unichar) -> Bool {
            (c >= 97 && c <= 122) || (c >= 65 && c <= 90) || c == 0x5F || c == 0x2D || c == 0x3A || c >= 0x80
        }
        func isIdentPart(_ c: unichar) -> Bool { isIdentStart(c) || (c >= 48 && c <= 57) }

        while i < n {
            let c = u[i]
            if !inTag {
                if eq("<!--", at: i) {
                    var j = i + 4
                    while j < n && !eq("-->", at: j) { j += 1 }
                    let end = j < n ? j + 3 : j
                    push(i, end, .comment)
                    i = end
                    continue
                }
                if c == 0x3C { // <
                    if eq("<!", at: i) { // doctype
                        var j = i
                        while j < n && u[j] != 0x3E { j += 1 }
                        let end = min(j + 1, n)
                        push(i, end, .comment)
                        i = end
                        continue
                    }
                    if eq("<?", at: i) {
                        var j = i
                        while j < n && !eq("?>", at: j) { j += 1 }
                        let end = min(j + 2, n)
                        push(i, end, .comment)
                        i = end
                        continue
                    }
                    if i + 1 < n && (isIdentStart(u[i + 1]) || u[i + 1] == 0x2F) {
                        inTag = true
                        push(i, i + 1, .punctuation)
                        i += 1
                        continue
                    }
                }
                i += 1
                continue
            }
            // inside tag
            if c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D { i += 1; continue }
            if c == 0x3E { // >
                inTag = false
                push(i, i + 1, .punctuation)
                i += 1
                continue
            }
            if c == 0x2F { // /
                push(i, i + 1, .punctuation)
                i += 1
                continue
            }
            if c == 0x3D { // =
                push(i, i + 1, .punctuation)
                i += 1
                continue
            }
            if c == 0x22 || c == 0x27 {
                let quote = c
                var j = i + 1
                while j < n && u[j] != quote { j += 1 }
                let end = min(j + 1, n)
                push(i, end, .string)
                i = end
                continue
            }
            if isIdentStart(c) {
                var j = i
                while j < n && isIdentPart(u[j]) { j += 1 }
                // tag name if followed by space/end/> and we just saw '<' or '</'; attribute otherwise
                var isTagName = false
                if i > 0 {
                    var k = i - 1
                    while k >= 0 && (u[k] == 0x20 || u[k] == 0x09 || u[k] == 0x0A) { k -= 1 }
                    if k >= 0 && u[k] == 0x3C { isTagName = true }
                }
                push(i, j, isTagName ? .keyword : .property)
                i = j
                continue
            }
            i += 1
        }
        return out
    }

    // MARK: Markdown

    static func markdownTokens(_ text: String) -> [(NSRange, TokenKind)] {
        var out: [(NSRange, TokenKind)] = []
        let s = text as NSString
        var inFence = false
        var fenceMarker: String = "```"

        s.enumerateSubstrings(in: NSRange(location: 0, length: s.length), options: [.byLines, .reverse]) {
            _, lineRange, _, _ in
            let line = s.substring(with: lineRange)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let localOffset = lineRange.location

            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                let marker = String(trimmed.prefix(3))
                if inFence && marker == fenceMarker {
                    inFence = false
                } else if !inFence {
                    inFence = true
                    fenceMarker = marker
                }
                out.append((lineRange, .keyword))
                return
            }
            if inFence {
                out.append((lineRange, .string))
                return
            }
            if trimmed.hasPrefix("#") {
                let hashes = trimmed.prefix { $0 == "#" }.count
                if hashes >= 1 && hashes <= 6 {
                    out.append((lineRange, .heading))
                    return
                }
            }
            if trimmed.hasPrefix(">") {
                out.append((lineRange, .comment))
                return
            }
            if trimmed == "---" || trimmed == "***" || trimmed == "===" {
                out.append((lineRange, .punctuation))
                return
            }
            // list markers
            if let r = trimmed.range(of: "^\\s*([-*+]|\\d+\\.)\\s", options: .regularExpression) {
                let mLen = trimmed.distance(from: r.lowerBound, to: r.upperBound)
                out.append((NSRange(location: localOffset, length: mLen), .punctuation))
            }
            inlineMarkdown(line, at: localOffset, into: &out)
        }
        // s.enumerateSubstrings byLines drops the trailing newline; the final line without \n is included,
        // but a fully empty document edge case is harmless.
        return out
    }

    private static func inlineMarkdown(_ line: String, at offset: Int, into out: inout [(NSRange, TokenKind)]) {
        let u = Array(line.utf16)
        let n = u.count
        var i = 0
        func push(_ start: Int, _ end: Int, _ kind: TokenKind) {
            if end > start { out.append((NSRange(location: offset + start, length: end - start), kind)) }
        }
        while i < n {
            let c = u[i]
            // inline code
            if c == 0x60 {
                var j = i + 1
                while j < n && u[j] != 0x60 { j += 1 }
                if j < n {
                    push(i, j + 1, .string)
                    i = j + 1
                    continue
                }
            }
            // bold **x** / __x__
            if i + 1 < n && ((u[i] == 0x2A && u[i + 1] == 0x2A) || (u[i] == 0x5F && u[i + 1] == 0x5F)) {
                var j = i + 2
                while j + 1 < n && !(u[j] == u[i] && u[j + 1] == u[i + 1]) { j += 1 }
                if j + 1 < n {
                    push(i, j + 2, .type)
                    i = j + 2
                    continue
                }
            }
            // italic *x* / _x_
            if c == 0x2A || c == 0x5F {
                var j = i + 1
                while j < n && u[j] != c { j += 1 }
                if j < n && j > i + 1 {
                    push(i, j + 1, .function)
                    i = j + 1
                    continue
                }
            }
            // link [text](url)
            if c == 0x5B {
                var j = i + 1
                var close: Int? = nil
                while j < n {
                    if u[j] == 0x5D { close = j; break }
                    j += 1
                }
                if let cl = close, cl + 1 < n, u[cl + 1] == 0x28 {
                    var k = cl + 2
                    while k < n && u[k] != 0x29 { k += 1 }
                    let end = min(k + 1, n)
                    push(i, end, .variable)
                    i = end
                    continue
                }
            }
            i += 1
        }
    }
}

// MARK: - Apply tokens to text storage

enum Highlighter {
    static func apply(to storage: NSTextStorage, tokens: [(NSRange, TokenKind)], theme: Theme, font: NSFont) {
        storage.beginEditing()
        let full = NSRange(location: 0, length: storage.length)
        storage.setAttributes(
            [.font: font, .foregroundColor: theme.editorText],
            range: full
        )
        let italic = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        let bold = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)

        for (range, kind) in tokens {
            guard range.location + range.length <= storage.length else { continue }
            var attrs: [NSAttributedString.Key: Any] = [:]
            switch kind {
            case .plain:
                continue
            case .comment:
                attrs[.foregroundColor] = theme.color(for: .comment)
                attrs[.font] = italic
            case .heading:
                attrs[.foregroundColor] = theme.color(for: .heading)
                attrs[.font] = bold
            default:
                attrs[.foregroundColor] = theme.color(for: kind)
            }
            storage.addAttributes(attrs, range: range)
        }
        storage.endEditing()
    }
}
