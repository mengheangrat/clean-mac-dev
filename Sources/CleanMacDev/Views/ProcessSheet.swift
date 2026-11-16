import SwiftUI

/// The processes using the most CPU or memory, refreshed every few seconds, with a Stop button each.
struct ProcessSheet: View {
    @EnvironmentObject var model: AppModel
    @State private var processes: [RunningProcess] = []
    @State private var sort = SortKey.cpu

    private enum SortKey { case cpu, memory, energy }

    private var top: [RunningProcess] {
        let sorted = processes.sorted {
            switch sort {
            case .cpu: return $0.cpu > $1.cpu
            case .memory: return $0.memory > $1.memory
            case .energy: return $0.energy > $1.energy
            }
        }
        return Array(sorted.prefix(20))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                IconTile(symbol: "gauge.with.dots.needle.67percent", color: .orange, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Heavy processes")
                        .font(.title2.weight(.bold))
                    Text("Your apps and tools using the most resources.")
                        .foregroundColor(.secondary)
                }
                Spacer()
                Picker("Sort by", selection: $sort) {
                    Text("CPU").tag(SortKey.cpu)
                    Text("Memory").tag(SortKey.memory)
                    Text("Energy").tag(SortKey.energy)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 220)
            }

            Card {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(top) { process in
                            row(for: process)
                            Divider()
                        }
                    }
                }
                .frame(height: 360)
            }

            HStack {
                Text("Apps are asked to quit, so they can save your work first.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Done") { model.activeSheet = nil }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 620)
        .task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    private func row(for process: RunningProcess) -> some View {
        HStack(spacing: 12) {
            Text(process.name)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            SizeText(text: String(format: "%.1f%%", process.cpu), isMuted: sort != .cpu)
            SizeText(text: process.memory.formattedBytes, isMuted: sort != .memory)
                .frame(minWidth: 80, alignment: .trailing)
            SizeText(text: String(format: "%.1f", process.energy), isMuted: sort != .energy)
                .frame(minWidth: 44, alignment: .trailing)
                .help("Energy Impact, as in Activity Monitor")
            Button("Stop") {
                ProcessMonitor.stop(process.id)
                Task { await refresh() }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func refresh() async {
        let list = await Task.detached { ProcessMonitor.list() }.value
        processes = list
    }
}
