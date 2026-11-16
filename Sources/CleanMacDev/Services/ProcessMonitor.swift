import AppKit

/// One running process owned by the current user.
struct RunningProcess: Identifiable {
    let id: pid_t
    let name: String
    let cpu: Double
    let memory: Int64
    var energy: Double = 0
}

/// Whole-machine CPU and memory use.
struct SystemUsage {
    var cpu: Double = 0
    var memoryUsed: Int64 = 0
    let memoryTotal = Int64(ProcessInfo.processInfo.physicalMemory)
    let cores = ProcessInfo.processInfo.activeProcessorCount
}

/// Lists the user's processes with their CPU and memory use, and stops them.
enum ProcessMonitor {
    /// The current user's processes, as reported by `ps`. Root processes can't be stopped, so they're left out.
    static func list() -> (processes: [RunningProcess], usage: SystemUsage) {
        let output = Shell.run("/bin/ps", ["-xco", "pid=,pcpu=,rss=,comm="]).output
        let me = ProcessInfo.processInfo.processIdentifier
        let (energy, cpu) = topSample()
        let processes = output.split(separator: "\n").compactMap { parse($0) }.filter { $0.id != me }.map {
            var process = $0
            process.energy = energy[process.id] ?? 0
            return process
        }
        return (processes, SystemUsage(cpu: cpu, memoryUsed: memoryUsed()))
    }

    /// Energy Impact per pid (as in Activity Monitor) and total CPU % busy. `top`'s first sample is always 0, so take the second.
    static func topSample() -> (energy: [pid_t: Double], cpu: Double) {
        let output = Shell.run("/usr/bin/top", ["-l", "2", "-s", "1", "-stats", "pid,power"]).output
        // Second sample starts at the second "Processes:" header; it holds "CPU usage: … 83.37% idle" then the PID table.
        guard let lastSample = output.components(separatedBy: "Processes:").last else { return ([:], 0) }
        var energy: [pid_t: Double] = [:]
        var cpu = 0.0
        for line in lastSample.split(separator: "\n") {
            if line.hasPrefix("CPU usage:"), let idle = line.split(separator: ",").last?
                .split(separator: "%").first.flatMap({ Double($0.trimmingCharacters(in: .whitespaces)) }) {
                cpu = 100 - idle
            }
            let fields = line.split(separator: " ")
            if fields.count == 2, let pid = pid_t(fields[0]), let power = Double(fields[1]) { energy[pid] = power }
        }
        return (energy, cpu)
    }

    /// "Memory Used" as Activity Monitor computes it: app memory + wired + compressed.
    static func memoryUsed() -> Int64 {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        let pages = Int64(stats.internal_page_count) - Int64(stats.purgeable_count)
            + Int64(stats.wire_count) + Int64(stats.compressor_page_count)
        return pages * Int64(vm_kernel_page_size)
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
