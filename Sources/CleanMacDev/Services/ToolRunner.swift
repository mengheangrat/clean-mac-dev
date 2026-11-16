import Foundation

/// Runs tool cleanups and deletes picker entries.
enum ToolRunner {
    /// Runs a tool's cleanup.
    /// - Returns: A description of the problem, or `nil` if it worked.
    static func run(_ action: ToolAction) -> String? {
        switch action {
        case .docker:
            return Shell.bash("docker system prune -a -f").succeeded ? nil : "Docker reported an error."

        case .homebrew:
            Shell.bash("brew cleanup -s")
            let downloads = Shell.bash("brew --cache").output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !downloads.isEmpty { FileCleaner.emptyFolder(downloads) }
            return nil

        case .pnpm:
            return Shell.bash("pnpm store prune").succeeded ? nil : "pnpm reported an error."

        case .brokenSimulators:
            return Shell.xcrun(["simctl", "delete", "unavailable"]).succeeded ? nil : "simctl reported an error."

        case .emptyTrash:
            let script = "tell application \"Finder\" to empty trash"
            if Shell.run("/usr/bin/osascript", ["-e", script]).succeeded { return nil }
            return "Finder didn't empty it. Allow Clean Mac Dev to control Finder in "
                + "System Settings › Privacy & Security › Automation."
        }
    }

    /// Deletes one simulator, runtime, emulator or system image.
    /// - Returns: `true` if it worked.
    static func delete(_ item: SubItem) -> Bool {
        switch item.action {
        case .deleteSimulator(let udid):
            return Shell.xcrun(["simctl", "delete", udid]).succeeded

        case .deleteRuntime(let id):
            return Shell.xcrun(["simctl", "runtime", "delete", id]).succeeded

        case .deletePaths(let paths, let pruneEmptyParent):
            let allRemoved = paths.map { FileCleaner.remove($0) }.allSatisfy { $0 }
            if pruneEmptyParent, let first = paths.first {
                FileCleaner.removeIfEmpty((first as NSString).deletingLastPathComponent)
            }
            return allRemoved
        }
    }

    /// Simulators must be shut down before they can be deleted.
    static func shutDownAllSimulators() {
        Shell.xcrun(["simctl", "shutdown", "all"])
    }

    /// Opens Docker Desktop and waits up to two minutes for it to be ready.
    /// - Returns: `true` if Docker is running.
    static func startDocker() -> Bool {
        Shell.run("/usr/bin/open", ["-a", "Docker"])
        for _ in 0..<40 {
            if Scanner.isDockerRunning() { return true }
            Thread.sleep(forTimeInterval: 3)
        }
        return false
    }
}
