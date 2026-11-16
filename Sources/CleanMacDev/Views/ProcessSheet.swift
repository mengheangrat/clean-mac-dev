import SwiftUI

/// The processes using the most CPU or memory, refreshed every few seconds, with a Stop button each.
struct ProcessSheet: View {
    @EnvironmentObject var model: AppModel
    @State private var processes: [RunningProcess] = []
    @State private var sortByMemory = false

    private var top: [RunningProcess] {
        let sorted = processes.sorted { sortByMemory ? $0.memory > $1.memory : $0.cpu > $1.cpu }
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
                Picker("Sort by", selection: $sortByMemory) {
                    Text("CPU").tag(false)
                    Text("Memory").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 160)
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
        .frame(width: 560)
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
            SizeText(text: String(format: "%.1f%%", process.cpu), isMuted: sortByMemory)
            SizeText(text: process.memory.formattedBytes, isMuted: !sortByMemory)
                .frame(minWidth: 80, alignment: .trailing)
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
