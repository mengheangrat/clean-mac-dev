import Foundation

/// One result of the security check.
struct SecurityFinding: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let isWarning: Bool
}

/// Looks for common signs of malware or a hijacked network, using only tools built into macOS.
/// This isn't an antivirus scan: it checks protections are on and flags what malware usually changes.
enum SecurityCheck {
    static func run() -> [SecurityFinding] {
        deviceProtections() + network() + startupItems() + networkProcesses()
    }

    private static func check(_ title: String, _ executable: String, _ args: [String], on: String,
                              good: String, bad: String) -> SecurityFinding {
        let isOn = Shell.run(executable, args).output.contains(on)
        return SecurityFinding(title: title, detail: isOn ? good : bad, isWarning: !isOn)
    }

    static func deviceProtections() -> [SecurityFinding] {
        [
            check("System Integrity Protection", "/usr/bin/csrutil", ["status"], on: "status: enabled",
                  good: "On. System files are protected.", bad: "Off. Malware can change system files."),
            check("Gatekeeper", "/usr/sbin/spctl", ["--status"], on: "assessments enabled",
                  good: "On. Only trusted apps can open.", bad: "Off. Any downloaded app can run unchecked."),
            check("FileVault", "/usr/bin/fdesetup", ["status"], on: "FileVault is On",
                  good: "On. Your disk is encrypted.", bad: "Off. Your files are readable if the Mac is stolen."),
            check("Firewall", "/usr/libexec/ApplicationFirewall/socketfilterfw", ["--getglobalstate"],
                  on: "enabled", good: "On. Incoming connections are filtered.",
                  bad: "Off. Turn it on in System Settings › Network › Firewall."),
        ]
    }

    static func network() -> [SecurityFinding] {
        // Adware and traffic-stealing malware usually set a proxy behind your back.
        let proxy = Shell.run("/usr/sbin/scutil", ["--proxy"]).output
        let proxyOn = ["HTTPEnable : 1", "HTTPSEnable : 1", "SOCKSEnable : 1", "ProxyAutoConfigEnable : 1"]
            .contains { proxy.contains($0) }
        let dns = Shell.run("/usr/sbin/scutil", ["--dns"]).output.split(separator: "\n")
            .filter { $0.contains("nameserver[") }
            .compactMap { $0.split(separator: ":", maxSplits: 1).last?.trimmingCharacters(in: .whitespaces) }
        let profiles = Shell.run("/usr/bin/profiles", ["list"]).output
        let hasProfiles = !profiles.isEmpty && !profiles.contains("no configuration profiles")
        return [
            SecurityFinding(title: "Web proxy",
                            detail: proxyOn ? "A proxy is set. If you didn't set it, your traffic may be redirected."
                                            : "None. Traffic goes straight to the internet.",
                            isWarning: proxyOn),
            SecurityFinding(title: "DNS servers",
                            detail: Array(Set(dns)).sorted().joined(separator: ", ") + ". Check you recognize these.",
                            isWarning: false),
            SecurityFinding(title: "Configuration profiles",
                            detail: hasProfiles ? "Profiles are installed. Remove any you didn't add in System Settings › Privacy & Security › Profiles."
                                                : "None installed.",
                            isWarning: hasProfiles),
        ]
    }

    /// Programs that start on their own whose code signature is missing or broken.
    static func startupItems() -> [SecurityFinding] {
        let folders = [Paths.inHome("Library/LaunchAgents"), "/Library/LaunchAgents", "/Library/LaunchDaemons"]
        var bad: [String] = []
        for folder in folders {
            for file in (try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? [] where file.hasSuffix(".plist") {
                let plist = NSDictionary(contentsOfFile: (folder as NSString).appendingPathComponent(file))
                let program = plist?["Program"] as? String ?? (plist?["ProgramArguments"] as? [String])?.first
                if let program, isUnsigned(program) { bad.append(file) }
            }
        }
        return [SecurityFinding(title: "Startup items",
                                detail: bad.isEmpty ? "All startup programs are properly signed."
                                                    : "Unsigned or modified: " + bad.joined(separator: ", "),
                                isWarning: !bad.isEmpty)]
    }

    /// Your processes with an open network connection whose code signature is missing or broken.
    static func networkProcesses() -> [SecurityFinding] {
        let pids = Set(Shell.run("/usr/sbin/lsof", ["-nPi", "-Fp"]).output.split(separator: "\n")
            .filter { $0.hasPrefix("p") }.map { String($0.dropFirst()) })
        guard !pids.isEmpty else { return [] }
        let paths = Set(Shell.run("/bin/ps", ["-o", "comm=", "-p", pids.joined(separator: ",")]).output
            .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.hasPrefix("/") })
        let bad = paths.filter(isUnsigned).map { ($0 as NSString).lastPathComponent }.sorted()
        return [SecurityFinding(title: "Apps using the network",
                                detail: bad.isEmpty ? "All \(paths.count) connected programs are properly signed."
                                                    : "Unsigned or modified: " + bad.joined(separator: ", "),
                                isWarning: !bad.isEmpty)]
    }

    /// A readable program whose signature is missing or broken. Scripts can't be signed and
    /// root-only files can't be read, so both are skipped rather than flagged.
    static func isUnsigned(_ path: String) -> Bool {
        guard let file = FileHandle(forReadingAtPath: path) else { return false }
        let start = (try? file.read(upToCount: 2)) ?? Data()
        try? file.close()
        return start != Data("#!".utf8) && !Shell.run("/usr/bin/codesign", ["--verify", path]).succeeded
    }
}
