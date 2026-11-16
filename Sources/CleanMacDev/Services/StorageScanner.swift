import Foundation

/// One file or folder and its size on disk.
struct StorageEntry: Identifiable {
    var id: String { path }
    let path: String
    let name: String
    let bytes: Int64

    var isFolder: Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}

/// Measures what macOS counts as "System Data", and how big each app is.
enum StorageScanner {
    /// Folders macOS lumps into "System Data": the Libraries, hidden home folders, swap and temp files.
    static func systemData() -> [StorageEntry] {
        let home = Paths.home
        let hiddenHomeFolders = contents(of: home, includeHidden: true)
            .filter { ($0 as NSString).lastPathComponent.hasPrefix(".") }
        let paths = contents(of: Paths.inHome("Library")) + hiddenHomeFolders + contents(of: "/Library")
            + ["/private/var/vm", "/private/var/folders"]
        return sizes(of: paths).map {
            StorageEntry(path: $0.path, name: $0.path.replacingOccurrences(of: home, with: "~"), bytes: $0.bytes)
        }
    }

    /// Everything in /Applications and ~/Applications.
    static func apps() -> [StorageEntry] {
        sizes(of: contents(of: "/Applications") + contents(of: Paths.inHome("Applications"))).map {
            StorageEntry(path: $0.path, name: ($0.name as NSString).deletingPathExtension, bytes: $0.bytes)
        }
    }

    /// What's inside a folder, for drilling down.
    static func children(of folder: String) -> [StorageEntry] {
        sizes(of: contents(of: folder, includeHidden: true))
    }

    /// Sizes of many paths with a single `du` call, largest first. Unreadable paths are skipped.
    static func sizes(of paths: [String]) -> [StorageEntry] {
        guard !paths.isEmpty else { return [] }
        // du exits non-zero when some protected file can't be read, but still prints the rest.
        let output = Shell.run("/usr/bin/du", ["-sk"] + paths).output
        return output.split(separator: "\n").compactMap { line -> StorageEntry? in
            let fields = line.split(separator: "\t", maxSplits: 1)
            guard fields.count == 2, let kilobytes = Int64(fields[0]), kilobytes > 0 else { return nil }
            let path = String(fields[1])
            return StorageEntry(path: path, name: (path as NSString).lastPathComponent, bytes: kilobytes * 1024)
        }
        .sorted { $0.bytes > $1.bytes }
    }

    private static func contents(of folder: String, includeHidden: Bool = false) -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? []
        return names
            .filter { includeHidden || !$0.hasPrefix(".") }
            .filter { $0 != ".Trash" }
            .map { (folder as NSString).appendingPathComponent($0) }
    }
}
