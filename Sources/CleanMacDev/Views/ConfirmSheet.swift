import SwiftUI

/// Review of everything that will be deleted, shown before cleaning starts.
struct ConfirmSheet: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let rows = model.selectionRows
        let warnings = model.warnings

        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                IconTile(symbol: "sparkles", color: .accentColor, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ready to clean")
                        .font(.title2.weight(.bold))
                    Text("At least \(model.selectionBytes.formattedBytes) will be freed.")
                        .foregroundColor(.secondary)
                }
            }

            Card {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(rows) { row in
                            SummaryRowView(row: row)
                        }
                    }
                }
                .frame(maxHeight: 240)
            }

            if !warnings.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundColor(.orange)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.1)))
            }

            Text("Deleted files don't go to the Trash, so this can't be undone.")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Spacer()
                Button("Cancel") { model.activeSheet = nil }
                    .controlSize(.large)
                    .keyboardShortcut(.cancelAction)
                Button("Clean Now") {
                    model.activeSheet = nil
                    model.clean()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 500)
    }
}

private struct SummaryRowView: View {
    let row: SummaryRow

    var body: some View {
        HStack(spacing: 10) {
            IconTile(symbol: row.icon, color: row.color, size: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(row.title)
                if !row.subtitle.isEmpty {
                    Text(row.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Text(row.bytes > 0 ? row.bytes.formattedBytes : "")
                .monospacedDigit()
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }
}
