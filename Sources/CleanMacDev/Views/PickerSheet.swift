import SwiftUI

/// Lists every simulator, runtime, emulator or system image of one kind, to pick which to delete.
struct PickerSheet: View {
    @EnvironmentObject var model: AppModel
    let item: CleanItem

    var body: some View {
        let entries = model.entries(for: item)
        let picked = entries.filter { model.selectedEntries.contains($0.id) }
        let pickedBytes = picked.reduce(Int64(0)) { $0 + $1.bytes }
        let largest = max(Int64(1), entries.map(\.bytes).max() ?? 1)

        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                IconTile(symbol: item.icon, color: item.color, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.title3.weight(.semibold))
                    Text(item.detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                Button("Select all") { model.setEntries(entries, selected: true) }
                    .buttonStyle(.link)
                Button("Select none") { model.setEntries(entries, selected: false) }
                    .buttonStyle(.link)
                Spacer()
                Text("\(picked.count) of \(entries.count) selected · \(pickedBytes.formattedBytes)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Card {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { pair in
                            EntryRow(entry: pair.element, color: item.color,
                                     fraction: Double(pair.element.bytes) / Double(largest))
                            if pair.offset < entries.count - 1 {
                                Divider().padding(.leading, 46)
                            }
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("Done") { model.activeSheet = nil }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 560, height: 520)
    }
}

/// One simulator, runtime, emulator or system image in the picker list.
private struct EntryRow: View {
    @EnvironmentObject var model: AppModel
    let entry: SubItem
    let color: Color
    let fraction: Double

    var body: some View {
        HStack(spacing: 12) {
            CheckBox(state: model.selectedEntries.contains(entry.id) ? .on : .off) {
                model.toggleEntry(entry.id)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.body.weight(.medium))
                if !entry.subtitle.isEmpty {
                    Text(entry.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if entry.bytes > 0 {
                SizeBar(fraction: fraction, color: color)
                    .frame(width: 70)
            }
            SizeText(text: entry.bytes > 0 ? entry.bytes.formattedBytes : "—", isMuted: entry.bytes == 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .onTapGesture { model.toggleEntry(entry.id) }
    }
}
