import Foundation

/// File operations that refuse to touch anything outside the home folder.
enum FileCleaner {
    static func isInsideHome(_ path: String) -> Bool {
        let homePrefix = Paths.home + "/"
        return path.hasPrefix(homePrefix)
            && path.count > homePrefix.count
            && !path.contains("/../")
    }

    /// Deletes everything inside `folder` but keeps the folder itself.
    /// - Returns: How many items couldn't be removed because they were in use or protected.
    @discardableResult
    static func emptyFolder(_ folder: String) -> Int {
        guard isInsideHome(folder),
              let names = try? FileManager.default.contentsOfDirectory(atPath: folder) else { return 0 }

        var skipped = 0
        for name in names {
            let path = (folder as NSString).appendingPathComponent(name)
            do {
                try FileManager.default.removeItem(atPath: path)
            } catch {
                skipped += 1
            }
        }
        return skipped
    }

    /// Deletes a file or folder.
    /// - Returns: `true` if it no longer exists.
    @discardableResult
    static func remove(_ path: String) -> Bool {
        guard isInsideHome(path) else { return false }
        guard FileManager.default.fileExists(atPath: path) else { return true }
        do {
            try FileManager.default.removeItem(atPath: path)
            return true
        } catch {
            return false
        }
    }

    /// Deletes `folder` only if nothing but `.DS_Store` is left in it.
    static func removeIfEmpty(_ folder: String) {
        guard isInsideHome(folder),
              let contents = try? FileManager.default.contentsOfDirectory(atPath: folder),
              contents.allSatisfy({ $0 == ".DS_Store" }) else { return }
        try? FileManager.default.removeItem(atPath: folder)
    }

    /// Visible subfolders of `folder`, sorted by name.
    static func subfolders(of folder: String) -> [String] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: folder) else { return [] }

        var result: [String] = []
        for name in names.sorted() where !name.hasPrefix(".") {
            let path = (folder as NSString).appendingPathComponent(name)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue {
                result.append(path)
            }
        }
        return result
    }
}
