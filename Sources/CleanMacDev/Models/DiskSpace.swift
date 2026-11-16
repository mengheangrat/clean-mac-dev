import Foundation

/// Free and total space on the disk that holds the home folder.
struct DiskSpace {
    var free: Int64 = 0
    var total: Int64 = 0

    /// Below this, the app warns that the disk is almost full.
    static let lowSpaceThreshold: Int64 = 20_000_000_000

    static func current() -> DiskSpace {
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]
        guard let values = try? URL(fileURLWithPath: Paths.home).resourceValues(forKeys: keys) else {
            return DiskSpace()
        }
        return DiskSpace(
            free: values.volumeAvailableCapacityForImportantUsage ?? 0,
            total: Int64(values.volumeTotalCapacity ?? 0)
        )
    }

    var used: Int64 { max(0, total - free) }

    var usedFraction: Double {
        total > 0 ? Double(used) / Double(total) : 0
    }

    var isLow: Bool { free < DiskSpace.lowSpaceThreshold }
}
