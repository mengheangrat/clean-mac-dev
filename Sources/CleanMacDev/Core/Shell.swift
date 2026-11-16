import Foundation

/// Runs command-line tools and collects their output.
enum Shell {
    struct Result {
        let status: Int32
        let output: String

        var succeeded: Bool { status == 0 }
    }

    /// Apps opened from Finder get a minimal PATH, so add where developer tools usually live.
    private static let environment: [String: String] = {
        var env = ProcessInfo.processInfo.environment
        let extraPaths = [
            Paths.inHome(".docker/bin"),
            "/Applications/Docker.app/Contents/Resources/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            Paths.inHome("Library/pnpm"),
            Paths.inHome(".local/bin"),
        ]
        let basePath = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        env["PATH"] = ([basePath] + extraPaths).joined(separator: ":")
        return env
    }()

    /// Runs an executable and waits for it to finish.
    @discardableResult
    static func run(_ executable: String, _ arguments: [String] = []) -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return Result(status: -1, output: "")
        }
        // Read before waiting, so a large output can't fill the pipe and block the tool.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return Result(status: process.terminationStatus, output: String(data: data, encoding: .utf8) ?? "")
    }

    /// Runs a command line through bash, so tools are looked up on PATH.
    @discardableResult
    static func bash(_ commandLine: String) -> Result {
        run("/bin/bash", ["-c", commandLine])
    }

    /// Runs an Xcode tool, for example `simctl`.
    @discardableResult
    static func xcrun(_ arguments: [String]) -> Result {
        run("/usr/bin/xcrun", arguments)
    }

    static func isInstalled(_ tool: Tool) -> Bool {
        bash("command -v \(tool.rawValue)").succeeded
    }

    /// Size on disk in bytes, as reported by `du`. Returns 0 if the path doesn't exist.
    static func diskUsage(of path: String) -> Int64 {
        guard FileManager.default.fileExists(atPath: path) else { return 0 }
        let output = run("/usr/bin/du", ["-sk", path]).output
        let firstField = output.split(whereSeparator: { $0 == "\t" || $0 == " " }).first ?? "0"
        return (Int64(String(firstField)) ?? 0) * 1024
    }
}
