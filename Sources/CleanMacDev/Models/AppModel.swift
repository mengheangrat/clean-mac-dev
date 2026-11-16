import SwiftUI

/// All state behind the main window: scan results, the user's selection, and cleaning progress.
final class AppModel: ObservableObject {
    let items = CleanItem.catalog

    // MARK: Scan results

    @Published private(set) var disk = DiskSpace.current()
    @Published private(set) var folderSizes: [String: Int64] = [:]
    @Published private(set) var pickerEntries: [PickerKind: [SubItem]] = [:]
    @Published private(set) var installedTools: [Tool: Bool] = [:]
    @Published private(set) var isDockerRunning = false
    @Published private(set) var dockerSummary = ""
    @Published private(set) var isStartingDocker = false
    @Published private(set) var hasScanned = false
    /// Item IDs, biggest first. Fixed at the end of each scan so rows don't jump around.
    @Published private(set) var displayOrder: [String] = []

    // MARK: Selection

    @Published var selectedItems: Set<String> = []
    @Published var selectedEntries: Set<String> = []

    // MARK: Progress

    @Published private(set) var isScanning = false
    @Published private(set) var isCleaning = false
    @Published private(set) var runStates: [String: RunState] = [:]
    @Published private(set) var progress: Double = 0
    @Published private(set) var statusText = ""
    @Published private(set) var lastResult: CleanResult? = nil

    @Published var activeSheet: SheetKind? = nil

    var isBusy: Bool { isScanning || isCleaning }

    init() {
        scan()
    }

    // MARK: - Scanning

    func scan() {
        guard !isBusy else { return }
        isScanning = true
        disk = .current()
        let items = self.items

        inBackground {
            var tools: [Tool: Bool] = [:]
            for tool in Tool.allCases { tools[tool] = Shell.isInstalled(tool) }
            let dockerRunning = tools[.docker] == true && Scanner.isDockerRunning()
            let summary = dockerRunning ? Scanner.dockerSummary() : ""
            onMain {
                self.installedTools = tools
                self.isDockerRunning = dockerRunning
                self.dockerSummary = summary
            }

            for item in items {
                guard let folder = item.folderPath else { continue }
                let size = Shell.diskUsage(of: folder)
                onMain { self.folderSizes[item.id] = size }
            }

            var entries: [PickerKind: [SubItem]] = [:]
            for item in items {
                guard let kind = item.pickerKind else { continue }
                let toolMissing = item.requiredTool.map { tools[$0] != true } ?? false
                entries[kind] = toolMissing ? [] : Scanner.subItems(for: kind)
            }
            onMain { self.finishScan(entries) }
        }
    }

    private func finishScan(_ entries: [PickerKind: [SubItem]]) {
        pickerEntries = entries
        let validIDs = Set(entries.values.joined().map(\.id))
        selectedEntries.formIntersection(validIDs)
        displayOrder = items.sorted { size(of: $0) > size(of: $1) }.map(\.id)

        if !hasScanned { selectSafeCaches() }
        hasScanned = true
        isScanning = false
        disk = .current()
    }

    /// First scan only: tick every non-empty cache, so one click on Clean does the safe thing.
    private func selectSafeCaches() {
        for item in items where item.group == .caches && size(of: item) > 0 {
            selectedItems.insert(item.id)
        }
    }

    // MARK: - Docker

    func startDocker() {
        isStartingDocker = true
        inBackground {
            let started = ToolRunner.startDocker()
            let summary = started ? Scanner.dockerSummary() : ""
            onMain {
                self.isStartingDocker = false
                self.isDockerRunning = started
                self.dockerSummary = summary
            }
        }
    }

    // MARK: - Cleaning

    private struct EntryJob {
        let parentID: String
        let entry: SubItem
    }

    func clean() {
        guard !isBusy else { return }

        let tasks = items.filter { !$0.isPicker && selectedItems.contains($0.id) && isAvailable($0) }
        var jobs: [EntryJob] = []
        for item in items {
            for entry in entries(for: item) where selectedEntries.contains(entry.id) {
                jobs.append(EntryJob(parentID: item.id, entry: entry))
            }
        }
        let stepCount = Double(max(1, tasks.count + jobs.count))

        isCleaning = true
        progress = 0
        lastResult = nil
        runStates = [:]
        for task in tasks { runStates[task.id] = .waiting }
        for job in jobs { runStates[job.parentID] = .waiting }
        let freeBefore = DiskSpace.current().free

        inBackground {
            var removedBytes: Int64 = 0
            var issues: [String] = []
            var stepsDone = 0.0

            func finishStep() {
                stepsDone += 1
                let fraction = stepsDone / stepCount
                onMain { self.progress = fraction }
            }

            for task in tasks {
                self.setRunState(.working, for: task.id, status: "Cleaning \(task.title)…")
                var succeeded = true

                if let folder = task.folderPath {
                    let sizeBefore = Shell.diskUsage(of: folder)
                    let skipped = FileCleaner.emptyFolder(folder)
                    removedBytes += max(0, sizeBefore - Shell.diskUsage(of: folder))
                    if skipped > 0 {
                        issues.append("\(task.title): \(skipped) item(s) were in use or protected and were skipped.")
                    }
                } else if let action = task.toolAction, let problem = ToolRunner.run(action) {
                    succeeded = false
                    issues.append("\(task.title): \(problem)")
                }

                self.setRunState(succeeded ? .done : .failed, for: task.id)
                finishStep()
            }

            if jobs.contains(where: { $0.entry.isSimulator }) {
                ToolRunner.shutDownAllSimulators()
            }

            var failedParents = Set<String>()
            for (index, job) in jobs.enumerated() {
                self.setRunState(.working, for: job.parentID, status: "Deleting \(job.entry.title)…")

                if ToolRunner.delete(job.entry) {
                    removedBytes += job.entry.bytes
                } else {
                    failedParents.insert(job.parentID)
                    issues.append("Couldn't delete \(job.entry.title).")
                }
                finishStep()

                let isLastForParent = index == jobs.count - 1 || jobs[index + 1].parentID != job.parentID
                if isLastForParent {
                    self.setRunState(failedParents.contains(job.parentID) ? .failed : .done, for: job.parentID)
                }
            }

            onMain {
                self.finishClean(removedBytes: removedBytes, freeBefore: freeBefore, issues: issues)
            }
        }
    }

    private func setRunState(_ state: RunState, for itemID: String, status: String? = nil) {
        onMain {
            self.runStates[itemID] = state
            if let status = status { self.statusText = status }
        }
    }

    private func finishClean(removedBytes: Int64, freeBefore: Int64, issues: [String]) {
        // The disk can take a moment to report freed space, so use whichever figure is larger.
        let diskFreed = max(0, DiskSpace.current().free - freeBefore)
        lastResult = CleanResult(freed: max(diskFreed, removedBytes), issues: issues)
        selectedItems.removeAll()
        selectedEntries.removeAll()
        isCleaning = false
        statusText = ""
        scan()
        activeSheet = .result
    }
}

// MARK: - Reading state

extension AppModel {
    func item(withID id: String) -> CleanItem? {
        items.first { $0.id == id }
    }

    /// Items in a section, biggest first once a scan has finished.
    func rows(in group: ItemGroup) -> [CleanItem] {
        let inGroup = items.filter { $0.group == group }
        guard !displayOrder.isEmpty else { return inGroup }
        return inGroup.sorted { rank(of: $0) < rank(of: $1) }
    }

    private func rank(of item: CleanItem) -> Int {
        displayOrder.firstIndex(of: item.id) ?? Int.max
    }

    /// Picker entries for an item; empty for other items or before scanning.
    func entries(for item: CleanItem) -> [SubItem] {
        guard let kind = item.pickerKind else { return [] }
        return pickerEntries[kind] ?? []
    }

    func hasLoadedEntries(for item: CleanItem) -> Bool {
        guard let kind = item.pickerKind else { return false }
        return pickerEntries[kind] != nil
    }

    func size(of item: CleanItem) -> Int64 {
        if item.isPicker {
            return entries(for: item).reduce(Int64(0)) { $0 + $1.bytes }
        }
        return folderSizes[item.id] ?? 0
    }

    /// Size of the biggest item, used to scale the size bars.
    var largestSize: Int64 {
        max(1, items.map { size(of: $0) }.max() ?? 1)
    }

    func sizeFraction(of item: CleanItem) -> Double {
        Double(size(of: item)) / Double(largestSize)
    }

    func sizeLabel(for item: CleanItem) -> String {
        if item.isPicker {
            guard hasLoadedEntries(for: item) else { return "…" }
            let bytes = size(of: item)
            return bytes > 0 ? bytes.formattedBytes : "—"
        }
        guard item.folderPath != nil else { return "" }
        guard let bytes = folderSizes[item.id] else { return "…" }
        return bytes > 0 ? bytes.formattedBytes : "Empty"
    }

    func totalSize(in group: ItemGroup) -> Int64 {
        items.filter { $0.group == group }.reduce(Int64(0)) { $0 + size(of: $1) }
    }

    func isToolMissing(for item: CleanItem) -> Bool {
        guard let tool = item.requiredTool else { return false }
        return installedTools[tool] == false
    }

    /// Whether the item's tool is installed (and Docker is running, for Docker).
    func isAvailable(_ item: CleanItem) -> Bool {
        if let tool = item.requiredTool, installedTools[tool] != true { return false }
        if item.isDocker && !isDockerRunning { return false }
        return true
    }

    func canSelect(_ item: CleanItem) -> Bool {
        guard !isBusy, isAvailable(item) else { return false }
        if item.isPicker { return !entries(for: item).isEmpty }
        if item.folderPath != nil { return size(of: item) > 0 }
        return true
    }

    /// Greyed-out rows: empty folders, empty lists and tools that aren't installed.
    func isDimmed(_ item: CleanItem) -> Bool {
        guard hasScanned else { return false }
        if isToolMissing(for: item) { return true }
        if item.isPicker { return entries(for: item).isEmpty }
        if item.folderPath != nil { return size(of: item) == 0 }
        return false
    }

    func detailText(for item: CleanItem) -> String {
        if isToolMissing(for: item) { return "Not installed on this Mac." }
        if item.isDocker && installedTools[.docker] == true {
            if !isDockerRunning { return "Docker Desktop isn't running. Start it to see what can be freed." }
            if !dockerSummary.isEmpty { return dockerSummary }
        }
        return item.detail
    }
}

// MARK: - Selection

extension AppModel {
    func checkState(for item: CleanItem) -> CheckState {
        guard item.isPicker else { return selectedItems.contains(item.id) ? .on : .off }
        let all = entries(for: item)
        let picked = pickedCount(for: item)
        if picked == 0 { return .off }
        return picked == all.count ? .on : .mixed
    }

    func pickedCount(for item: CleanItem) -> Int {
        entries(for: item).filter { selectedEntries.contains($0.id) }.count
    }

    /// Ticks or unticks a row; picker rows open their list instead.
    func toggle(_ item: CleanItem) {
        guard canSelect(item) else { return }
        if item.isPicker {
            activeSheet = .picker(item.id)
        } else if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }

    func toggleEntry(_ id: String) {
        guard !isBusy else { return }
        if selectedEntries.contains(id) {
            selectedEntries.remove(id)
        } else {
            selectedEntries.insert(id)
        }
    }

    func setEntries(_ entries: [SubItem], selected: Bool) {
        for entry in entries {
            if selected { selectedEntries.insert(entry.id) } else { selectedEntries.remove(entry.id) }
        }
    }

    private var selectableCaches: [CleanItem] {
        items.filter { $0.group == .caches && canSelect($0) }
    }

    var allCachesSelected: Bool {
        let caches = selectableCaches
        return !caches.isEmpty && caches.allSatisfy { selectedItems.contains($0.id) }
    }

    func toggleAllCaches() {
        let deselect = allCachesSelected
        for item in selectableCaches {
            if deselect { selectedItems.remove(item.id) } else { selectedItems.insert(item.id) }
        }
    }

    // MARK: Summary of the selection

    var selectionRows: [SummaryRow] {
        var rows: [SummaryRow] = []
        for item in items where !item.isPicker && selectedItems.contains(item.id) && isAvailable(item) {
            rows.append(SummaryRow(id: item.id, title: item.title, subtitle: "",
                                   bytes: size(of: item), icon: item.icon, color: item.color))
        }
        for item in items {
            for entry in entries(for: item) where selectedEntries.contains(entry.id) {
                let subtitle = entry.subtitle.isEmpty ? item.title : "\(item.title) · \(entry.subtitle)"
                rows.append(SummaryRow(id: entry.id, title: entry.title, subtitle: subtitle,
                                       bytes: entry.bytes, icon: item.icon, color: item.color))
            }
        }
        return rows
    }

    var selectionCount: Int { selectionRows.count }

    var selectionBytes: Int64 { selectionRows.reduce(Int64(0)) { $0 + $1.bytes } }

    var selectedToolNames: [String] {
        items.filter { $0.group == .tools && selectedItems.contains($0.id) && isAvailable($0) }.map(\.title)
    }

    var warnings: [String] {
        func picked(_ kind: PickerKind) -> Bool {
            (pickerEntries[kind] ?? []).contains { selectedEntries.contains($0.id) }
        }
        var result: [String] = []
        if picked(.simulators) { result.append("Deleted iOS simulators lose their installed apps and data.") }
        if picked(.androidEmulators) { result.append("Deleted Android emulators lose their installed apps and data.") }
        if picked(.runtimes) { result.append("Deleted iOS versions must be downloaded again in Xcode.") }
        if picked(.systemImages) {
            result.append("Emulators that use a deleted system image won't start until it's re-installed.")
        }
        if selectedItems.contains("docker") && isDockerRunning {
            result.append("Docker removes all stopped containers and unused images. Volumes are kept.")
        }
        if selectedItems.contains("appcaches") {
            result.append("Quit other apps first so their caches can be removed.")
        }
        return result
    }
}
