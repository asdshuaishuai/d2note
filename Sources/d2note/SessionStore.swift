import Foundation

// MARK: - Session persistence (draft autosave)

struct SavedTab: Codable {
    /// Absolute path for file-backed tabs; nil for untitled tabs.
    var path: String?
    /// Display title kept for untitled tabs (e.g. from the Services capture).
    var title: String?
    /// Untitled tabs: full content. File tabs: unsaved overlay, nil when clean.
    var draft: String?
    var caret: Int
}

struct SavedSession: Codable {
    var tabs: [SavedTab]
    var activeIndex: Int
}

/// Stores the open-tab session under ~/Library/Application Support/d2note/
/// so drafts and unsaved edits survive relaunch. Written atomically.
final class SessionStore {

    static let shared = SessionStore()

    private let fileURL: URL

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("d2note", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("session.json")
    }

    func save(_ session: SavedSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        // atomic write on a background queue; last writer wins
        let url = fileURL
        DispatchQueue.global(qos: .utility).async {
            try? data.write(to: url, options: .atomic)
        }
    }

    func load() -> SavedSession? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(SavedSession.self, from: data)
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
