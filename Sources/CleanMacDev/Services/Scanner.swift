import Foundation

/// Finds simulators, runtimes, emulators and system images, and asks Docker what it can free.
enum Scanner {
    static func subItems(for kind: PickerKind) -> [SubItem] {
        switch kind {
        case .simulators: return simulators()
        case .runtimes: return runtimes()
        case .androidEmulators: return androidEmulators()
        case .systemImages: return systemImages()
        }
    }

    // MARK: Docker

    static func isDockerRunning() -> Bool {
        Shell.bash("docker info").succeeded
    }

    /// For example "Images: 30GB (78%)  ·  Build Cache: 2GB".
    static func dockerSummary() -> String {
        Shell.bash("docker system df --format '{{.Type}}: {{.Reclaimable}}'")
            .output
            .split(separator: "\n")
            .joined(separator: "  ·  ")
    }

    // MARK: Xcode

    /// "com.apple.CoreSimulator.SimRuntime.iOS-17-0" becomes "iOS 17.0".
    static func runtimeName(_ identifier: String) -> String {
        let lastPart = identifier.components(separatedBy: ".").last ?? identifier
        let pieces = lastPart.components(separatedBy: "-")
        guard pieces.count >= 2 else { return lastPart }
        return pieces[0] + " " + pieces[1...].joined(separator: ".")
    }

    private static func simulators() -> [SubItem] {
        guard let json = parseJSON(Shell.xcrun(["simctl", "list", "devices", "-j"])),
              let devicesByRuntime = json["devices"] as? [String: Any] else { return [] }

        var result: [SubItem] = []
        for (runtime, value) in devicesByRuntime {
            guard let devices = value as? [[String: Any]] else { continue }
            for device in devices {
                guard let udid = device["udid"] as? String,
                      let name = device["name"] as? String else { continue }

                var details = [runtimeName(runtime)]
                if let state = device["state"] as? String, !state.isEmpty { details.append(state) }
                if device["isAvailable"] as? Bool == false { details.append("unavailable") }

                let folder = Paths.inHome("Library/Developer/CoreSimulator/Devices/\(udid)")
                result.append(SubItem(
                    id: "sim:\(udid)",
                    title: name,
                    subtitle: details.joined(separator: " · "),
                    bytes: Shell.diskUsage(of: folder),
                    action: .deleteSimulator(udid: udid)
                ))
            }
        }
        return result.sorted { $0.bytes > $1.bytes }
    }

    private static func runtimes() -> [SubItem] {
        guard let json = parseJSON(Shell.xcrun(["simctl", "runtime", "list", "-j"])) else { return [] }

        var result: [SubItem] = []
        for (key, value) in json {
            guard let runtime = value as? [String: Any] else { continue }
            let id = runtime["identifier"] as? String ?? key
            let version = runtime["version"] as? String ?? ""
            let runtimeIdentifier = runtime["runtimeIdentifier"] as? String ?? ""

            var details: [String] = []
            if let build = runtime["build"] as? String, !build.isEmpty { details.append(build) }
            if let state = runtime["state"] as? String, !state.isEmpty { details.append(state) }

            result.append(SubItem(
                id: "rt:\(id)",
                title: runtimeIdentifier.isEmpty ? "Runtime \(version)" : runtimeName(runtimeIdentifier),
                subtitle: details.joined(separator: " · "),
                bytes: (runtime["sizeBytes"] as? NSNumber)?.int64Value ?? 0,
                action: .deleteRuntime(id: id)
            ))
        }
        return result.sorted { $0.bytes > $1.bytes }
    }

    private static func parseJSON(_ result: Shell.Result) -> [String: Any]? {
        guard result.succeeded, let data = result.output.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    // MARK: Android

    private static func androidEmulators() -> [SubItem] {
        let avdFolder = Paths.inHome(".android/avd")
        var result: [SubItem] = []
        for folder in FileCleaner.subfolders(of: avdFolder) where folder.hasSuffix(".avd") {
            let name = ((folder as NSString).lastPathComponent as NSString).deletingPathExtension
            let iniFile = (folder as NSString).deletingPathExtension + ".ini"
            result.append(SubItem(
                id: "avd:\(folder)",
                title: name.replacingOccurrences(of: "_", with: " "),
                subtitle: "Android emulator",
                bytes: Shell.diskUsage(of: folder),
                action: .deletePaths([folder, iniFile], pruneEmptyParent: false)
            ))
        }
        return result.sorted { $0.bytes > $1.bytes }
    }

    private static func systemImages() -> [SubItem] {
        let imagesFolder = Paths.inHome("Library/Android/sdk/system-images")
        var result: [SubItem] = []
        for apiFolder in FileCleaner.subfolders(of: imagesFolder) {
            let apiName = (apiFolder as NSString).lastPathComponent
            for variantFolder in FileCleaner.subfolders(of: apiFolder) {
                let variantName = (variantFolder as NSString).lastPathComponent
                result.append(SubItem(
                    id: "img:\(variantFolder)",
                    title: apiName.replacingOccurrences(of: "android-", with: "Android API "),
                    subtitle: variantName.replacingOccurrences(of: "_", with: " "),
                    bytes: Shell.diskUsage(of: variantFolder),
                    action: .deletePaths([variantFolder], pruneEmptyParent: true)
                ))
            }
        }
        return result.sorted { $0.bytes > $1.bytes }
    }
}
