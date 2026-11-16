import SwiftUI

/// Sticky bar with the selection total and the Clean button.
struct BottomBar: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 16) {
                status
                Spacer()
                Button { model.activeSheet = .confirm } label: {
                    Text(model.isCleaning ? "Cleaning…" : "Clean")
                        .frame(minWidth: 96)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(model.isBusy || model.selectionCount == 0)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .background(.bar)
    }

    @ViewBuilder private var status: some View {
        if model.isCleaning {
            VStack(alignment: .leading, spacing: 6) {
                Text(model.statusText)
                    .font(.callout)
                    .lineLimit(1)
                ProgressView(value: model.progress)
                    .frame(maxWidth: 380)
            }
        } else if model.selectionCount == 0 {
            Text(model.isScanning ? "Scanning…" : "Tick what you want to clean.")
                .foregroundColor(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(model.selectionBytes.formattedBytes) selected")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Text(selectionCaption)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var selectionCaption: String {
        let count = model.selectionCount
        var caption = "\(count) item" + (count == 1 ? "" : "s")
        let tools = model.selectedToolNames
        if !tools.isEmpty {
            caption += ", including " + tools.joined(separator: ", ")
        }
        return caption
    }
}
