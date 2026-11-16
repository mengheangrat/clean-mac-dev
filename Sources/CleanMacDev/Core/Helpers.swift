import Foundation

/// Locations inside the user's home folder.
enum Paths {
    static let home = NSHomeDirectory()

    /// Builds an absolute path from one relative to the home folder.
    static func inHome(_ relativePath: String) -> String {
        (home as NSString).appendingPathComponent(relativePath)
    }
}

extension Int64 {
    /// Human-readable size, for example "1.2 GB".
    var formattedBytes: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}

/// Runs `work` on the main thread, where UI state may be changed.
func onMain(_ work: @escaping () -> Void) {
    DispatchQueue.main.async(execute: work)
}

/// Runs `work` on a background thread, for slow disk and tool operations.
func inBackground(_ work: @escaping () -> Void) {
    DispatchQueue.global(qos: .userInitiated).async(execute: work)
}
