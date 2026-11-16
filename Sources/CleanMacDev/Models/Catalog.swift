import SwiftUI

extension CleanItem {
    /// Everything the app knows how to clean.
    /// To support a new cache folder, add a `cache(...)` line here.
    static let catalog: [CleanItem] = [
        // MARK: Caches
        cache("deriveddata", "Xcode build cache", "DerivedData. Rebuilt on your next build.",
              path: "Library/Developer/Xcode/DerivedData", icon: "hammer.fill", color: .blue),
        cache("devicesupport", "Xcode iOS device support", "Re-created when you connect an iPhone.",
              path: "Library/Developer/Xcode/iOS DeviceSupport", icon: "iphone", color: .indigo),
        cache("simcaches", "iOS simulator caches", "Rebuilt when a simulator starts.",
              path: "Library/Developer/CoreSimulator/Caches", icon: "square.stack.3d.up.fill", color: .teal),
        cache("npm", "npm cache", "Packages download again when needed.",
              path: ".npm/_cacache", icon: "shippingbox.fill", color: .red),
        cache("gradle", "Gradle caches", "Dependencies download again on the next build.",
              path: ".gradle/caches", icon: "cube.fill", color: .green),
        cache("gradlewrapper", "Gradle wrapper downloads", "Gradle versions download again when needed.",
              path: ".gradle/wrapper/dists", icon: "arrow.down.circle.fill", color: .mint),
        cache("gradledaemon", "Gradle daemon logs", "Old daemon logs and state.",
              path: ".gradle/daemon", icon: "doc.text.fill", color: .green),
        cache("maven", "Maven downloads", "~/.m2/repository. Your settings.xml is kept.",
              path: ".m2/repository", icon: "archivebox.fill", color: .orange),
        cache("cocoapods", "CocoaPods spec repos", "Downloads again on the next pod install.",
              path: ".cocoapods/repos", icon: "circle.hexagongrid.fill", color: .pink),
        cache("dotcache", "Tool caches", "~/.cache. Includes downloaded AI models, if any.",
              path: ".cache", icon: "folder.fill", color: .gray),
        cache("appcaches", "App caches", "~/Library/Caches. Quit apps first; files in use are skipped.",
              path: "Library/Caches", icon: "square.grid.2x2.fill", color: .purple),
        cache("logs", "App logs", "~/Library/Logs. Old log files.",
              path: "Library/Logs", icon: "list.bullet.rectangle.fill", color: .brown),

        // MARK: Simulators & emulators
        picker("sims", .simulators, "iOS simulators",
               "Each one keeps its own apps and data. Add simulators again in Xcode.",
               icon: "iphone.gen2", color: .blue, requires: .xcrun),
        picker("runtimes", .runtimes, "iOS simulator runtimes",
               "Whole iOS versions. Download again in Xcode › Settings › Components.",
               icon: "cpu", color: .indigo, requires: .xcrun),
        picker("avds", .androidEmulators, "Android emulators",
               "Each one keeps its own apps and data. Create again in Device Manager.",
               icon: "smartphone", color: .green),
        picker("sysimages", .systemImages, "Android system images",
               "Emulators need their image. Re-install in Android Studio › SDK Manager.",
               icon: "externaldrive.fill", color: .mint),

        // MARK: Tools
        tool("docker", .docker, "Docker unused data",
             "Stopped containers, unused images and build cache. Volumes are kept.",
             icon: "server.rack", color: .cyan, requires: .docker),
        tool("brew", .homebrew, "Homebrew leftovers", "Old versions and downloads.",
             icon: "mug.fill", color: .orange, requires: .brew),
        tool("pnpm", .pnpm, "pnpm unused packages", "Packages no project uses any more.",
             icon: "shippingbox", color: .yellow, requires: .pnpm),
        tool("unavailable", .brokenSimulators, "Broken iOS simulators", "Leftovers from old Xcode versions.",
             icon: "xmark.bin.fill", color: .red, requires: .xcrun),
        tool("trash", .emptyTrash, "Empty the Trash", "Asks Finder to empty it.",
             icon: "trash.fill", color: .gray),
    ]

    private static func cache(_ id: String, _ title: String, _ detail: String,
                              path: String, icon: String, color: Color) -> CleanItem {
        CleanItem(id: id, title: title, detail: detail, group: .caches,
                  kind: .folder(Paths.inHome(path)), icon: icon, color: color)
    }

    private static func picker(_ id: String, _ kind: PickerKind, _ title: String, _ detail: String,
                               icon: String, color: Color, requires tool: Tool? = nil) -> CleanItem {
        CleanItem(id: id, title: title, detail: detail, group: .devices,
                  kind: .picker(kind), icon: icon, color: color, requiredTool: tool)
    }

    private static func tool(_ id: String, _ action: ToolAction, _ title: String, _ detail: String,
                             icon: String, color: Color, requires tool: Tool? = nil) -> CleanItem {
        CleanItem(id: id, title: title, detail: detail, group: .tools,
                  kind: .tool(action), icon: icon, color: color, requiredTool: tool)
    }
}
