import AppKit

// Capture ObjC exceptions (Swift cannot catch them) so they land in a file.
let originalHandler = NSGetUncaughtExceptionHandler()
NSSetUncaughtExceptionHandler { exception in
    let text = "\(Date()) UNCAUGHT: \(exception.name.rawValue) — \(exception.reason ?? "?")\n\(exception.callStackSymbols.joined(separator: "\n"))\n"
    try? text.write(toFile: "/tmp/d2note_exception.log", atomically: true, encoding: .utf8)
    originalHandler?(exception)
}

let app = NSApplication.shared
let appDelegate = AppDelegate()
app.delegate = appDelegate
app.setActivationPolicy(.regular)
app.run()
