import Foundation

/// Embedded sample files shown on first launch (no bundle resources needed).
enum SampleContent {

    static let files: [(name: String, content: String)] = [
        ("Sample.swift", swiftSample),
        ("sample.json", jsonSample),
        ("notes.md", markdownSample),
        ("script.py", pythonSample),
        ("index.html", htmlSample),
    ]

    static let swiftSample = #"""
// d2note 欢迎示例 — 这是一个 Swift 文件
// 试试这些快捷键：
//   ⌘F 查找 / ⌥⌘F 替换 / ⌘L 跳转到行 / ⌘/ 切换注释
//   ⌥⇧F 智能缩进 / ⌘⇧J 格式化 JSON / ⌘W 关闭标签

import Foundation

/// 一个展示语法高亮的示例结构体
struct Welcome {
    let name: String = "d2note"
    var version = 1.0
    private let features: [String] = ["多标签页", "语法高亮", "自动缩进", "查找替换"]

    func greet(times: Int) -> String {
        var message = "你好，\(name) 👋"
        for _ in 0..<max(0, times) {
            message += "!"
        }
        return message
    }

    func featureList() -> String {
        features.joined(separator: " · ")
    }
}

enum Language: String, CaseIterable {
    case swift, python, javascript, go, rust
    case json, markdown, shell

    var icon: String {
        switch self {
        case .swift, .python, .javascript, .go, .rust: return "🦅"
        case .json, .markdown: return "📄"
        case .shell: return "🐚"
        }
    }
}

let welcome = Welcome()
print(welcome.greet(times: 3))
print("支持的语言: \(Language.allCases.map(\.rawValue).joined(separator: ", "))")

// 数字与正则字面量
let numbers: [Double] = [3.14159, 0xFF, 0b1010, 1_000_000, 1.5e-8]
let pattern = #"^\w+@\w+\.\w+$"#
print(numbers, pattern)
"""#

    static let jsonSample = """
    {
        "//": "JSON 示例：键和值使用不同颜色，⌘⇧J 可格式化，试试把它压扁后再格式化",
        "app": {
            "name": "d2note",
            "version": "1.0.0",
            "tags": ["editor", "macos", "swift"],
            "settings": {
                "theme": "dark",
                "fontSize": 13,
                "tabWidth": 4,
                "wordWrap": false,
                "autoClosePairs": true
            }
        },
        "languages": 21,
        "openSource": true,
        "stars": 4242,
        "rating": 9.5,
        "author": null
    }
    """

    static let markdownSample = #"""
    # d2note 使用笔记

    一个用 **Swift + AppKit** 写的轻量文本编辑器，向 Notepad++ 致敬。

    ## 快捷键速查

    | 功能 | 快捷键 |
    |------|--------|
    | 新建标签 | `⌘N` |
    | 打开文件 | `⌘O` |
    | 保存 | `⌘S` |
    | 查找 / 替换 | `⌘F` / `⌥⌘F` |
    | 跳转到行 | `⌘L` |
    | 切换注释 | `⌘/` |
    | 格式化 JSON | `⌘⇧J` |
    | 智能缩进 | `⌥⇧F` |
    | 自动换行 | `⌥⌘W` |

    ## 编辑器特性

    - 支持 20+ 种语言的语法高亮，打开文件自动识别
    - 括号/引号自动补全，输入 `(` `"` 试试
    - 智能缩进：回车自动延续缩进，`Tab`/`Shift+Tab` 整体缩进
    - 括号配对高亮、当前行高亮、行号栏
    - 多标签页，可拖拽排序，`⌘⇧[` `⌘⇧]` 切换
    - 深色 / 浅色主题，字号 `⌘=` `⌘-` 调节

    > 小贴士：把文件拖进窗口即可打开，底部状态栏可以手动切换语言。

    ### 代码块示例

    ```python
    def hello(name="world"):
        print(f"Hello, {name}!")

    hello("d2note")
    ```

    祝使用愉快 · [反馈问题](https://example.com)
    """#

    static let pythonSample = """
    #!/usr/bin/env python3
    # -*- coding: utf-8 -*-
    \"\"\"Python 高亮示例\"\"\"

    import os
    from dataclasses import dataclass


    @dataclass
    class Notebook:
        name: str
        tabs: int = 1
        dirty: bool = False

        def describe(self) -> str:
            status = "未保存" if self.dirty else "已保存"
            return f"{self.name}: {self.tabs} 个标签 ({status})"


    def fibonacci(limit):
        a, b = 0, 1
        while a < limit:
            yield a
            a, b = b, a + b


    if __name__ == "__main__":
        book = Notebook(name="我的笔记", tabs=5, dirty=True)
        print(book.describe())
        print(list(fibonacci(100)))
        print("路径:", os.getcwd())
    """

    static let htmlSample = """
    <!DOCTYPE html>
    <html lang="zh-CN">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>d2note</title>
        <style>
            body {
                font-family: -apple-system, sans-serif;
                background: #1e222a;
                color: #abb2bf;
                margin: 2rem;
            }
            .badge { color: #61afef; font-weight: bold; }
        </style>
    </head>
    <body>
        <!-- HTML 高亮示例：标签、属性、字符串各有颜色 -->
        <h1>Hello, <span class="badge">d2note</span></h1>
        <p>这是一个 HTML 示例文件。</p>
        <ul>
            <li>自动识别语言</li>
            <li>语法高亮</li>
        </ul>
    </body>
    </html>
    """
}
