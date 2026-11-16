import AppKit
import SwiftUI

/// What fills "System Data" and which apps are biggest, with drill-down into folders.
struct StorageSheet: View {
    @EnvironmentObject var model: AppModel
    @State private var tab = Tab.systemData
    @State private var trail: [StorageEntry] = []
    @State private var entries: [StorageEntry] = []
    @State private var isLoading = false

    private enum Tab { case systemData, apps }

    private var largest: Int64 { entries.first?.bytes ?? 1 }
    private var total: Int64 { entries.reduce(0) { $0 + $1.bytes } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                IconTile(symbol: "internaldrive", color: .purple, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Storage")
                        .font(.title2.weight(.bold))
                    Text("What's taking up space on your Mac.")
                        .foregroundColor(.secondary)
                }
                Spacer()
                Picker("Show", selection: $tab) {
                    Text("System Data").tag(Tab.systemData)
                    Text("Apps").tag(Tab.apps)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 220)
            }

            HStack(spacing: 8) {
                Button { trail.removeLast() } label: { Image(systemName: "chevron.left") }
                    .disabled(trail.isEmpty || isLoading)
                Text(trail.last?.path.replacingOccurrences(of: Paths.home, with: "~")
                     ?? (tab == .systemData ? "Libraries, hidden folders, swap and temp files" : "Applications"))
                    .lineLimit(1)
                    .truncationMode(.head)
                    .foregroundColor(.secondary)
                Spacer()
                if !isLoading { SizeText(text: "\(total.formattedBytes) total") }
            }

            Card {
                Group {
                    if isLoading {
                        VStack(spacing: 10) {
                            ProgressView()
                            Text("Measuring folders…").foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(entries.prefix(60)) { entry in
                                    row(for: entry)
                                    Divider()
                                }
                            }
                        }
                    }
                }
                .frame(height: 400)
            }

            HStack {
                Text("Click a folder to see what's inside. Protected system files can't be measured.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Done") { model.activeSheet = nil }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 680)
        .task(id: "\(tab)|\(trail.last?.path ?? "")") { await load() }
        .onChange(of: tab) { _ in trail = [] }
    }

    private func row(for entry: StorageEntry) -> some View {
        // .app bundles are folders too, but their insides aren't useful to browse.
        let canOpen = entry.isFolder && !entry.path.hasSuffix(".app")
        return HStack(spacing: 12) {
            Image(systemName: canOpen ? "folder" : (entry.path.hasSuffix(".app") ? "app" : "doc"))
                .foregroundColor(.secondary)
                .frame(width: 18)
            Text(entry.name)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 280, alignment: .leading)
            SizeBar(fraction: Double(entry.bytes) / Double(largest), color: .purple)
            SizeText(text: entry.bytes.formattedBytes)
                .frame(minWidth: 70, alignment: .trailing)
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: entry.path)])
            } label: { Image(systemName: "magnifyingglass") }
                .buttonStyle(.borderless)
                .help("Show in Finder")
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .opacity(canOpen ? 1 : 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture { if canOpen { trail.append(entry) } }
    }

    private func load() async {
        isLoading = true
        let folder = trail.last?.path
        let currentTab = tab
        let result = await Task.detached { () -> [StorageEntry] in
            if let folder { return StorageScanner.children(of: folder) }
            return currentTab == .systemData ? StorageScanner.systemData() : StorageScanner.apps()
        }.value
        guard !Task.isCancelled else { return }
        entries = result
        isLoading = false
    }
}
