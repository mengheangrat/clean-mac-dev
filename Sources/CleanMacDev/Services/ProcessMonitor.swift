import AppKit

/// One running process owned by the current user.
struct RunningProcess: Identifiable {
    let id: pid_t
    let name: String
    let cpu: Double
    let memory: Int64
    var energy: Double = 0
}

/// Lists the user's processes with their CPU and memory use, and stops them.
enum ProcessMonitor {
    /// The current user's processes, as reported by `ps`. Root processes can't be stopped, so they're left out.
    static func list() -> [RunningProcess] {
        let output = Shell.run("/bin/ps", ["-xco", "pid=,pcpu=,rss=,comm="]).output
        let me = ProcessInfo.processInfo.processIdentifier
        let energy = energyImpact()
        return output.split(separator: "\n").compactMap { parse($0) }.filter { $0.id != me }.map {
            var process = $0
            process.energy = energy[process.id] ?? 0
            return process
        }
    }

    /// Energy Impact per pid, the same number Activity Monitor shows. `top`'s first sample is always 0, so take the second.
    static func energyImpact() -> [pid_t: Double] {
        let output = Shell.run("/usr/bin/top", ["-l", "2", "-s", "1", "-stats", "pid,power"]).output
        guard let lastSample = output.components(separatedBy: "PID").last else { return [:] }
        var result: [pid_t: Double] = [:]
        for line in lastSample.split(separator: "\n") {
            let fields = line.split(separator: " ")
            if fields.count == 2, let pid = pid_t(fields[0]), let power = Double(fields[1]) { result[pid] = power }
        }
        return result
    }

    /// Parses one `ps` line: "  pid  cpu  rssKB  name with spaces".
    static func parse(_ line: Substring) -> RunningProcess? {
        let fields = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
        guard fields.count == 4, let pid = pid_t(fields[0]), let cpu = Double(fields[1]),
              let rss = Int64(fields[2]) else { return nil }
        return RunningProcess(id: pid, name: String(fields[3]), cpu: cpu, memory: rss * 1024)
    }

    /// Asks an app to quit (so it can offer to save), or sends SIGTERM to anything else.
    @discardableResult
    static func stop(_ pid: pid_t) -> Bool {
        if let app = NSRunningApplication(processIdentifier: pid) { return app.terminate() }
        return kill(pid, SIGTERM) == 0
    }
}
