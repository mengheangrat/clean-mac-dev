import SwiftUI

/// One cleanable item: checkbox, icon, description, and size.
struct ItemRow: View {
    @EnvironmentObject var model: AppModel
    let item: CleanItem
    @State var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            CheckBox(state: model.checkState(for: item)) { model.toggle(item) }
                .disabled(!model.canSelect(item))
            IconTile(symbol: item.icon, color: item.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body.weight(.medium))
                Text(model.detailText(for: item))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            accessories
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isHovering && model.canSelect(item) ? Color.primary.opacity(0.04) : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture { model.toggle(item) }
        .opacity(model.isDimmed(item) ? 0.5 : 1)
    }

    private var accessories: some View {
        HStack(spacing: 12) {
            if let state = model.runStates[item.id] {
                RunStateIcon(state: state)
            }
            if item.isDocker {
                dockerControls
            }
            if item.isPicker && model.canSelect(item) {
                pickerControls
            }
            if item.group != .tools {
                if model.size(of: item) > 0 {
                    SizeBar(fraction: model.sizeFraction(of: item), color: item.color)
                        .frame(width: 70)
                }
                SizeText(text: model.sizeLabel(for: item), isMuted: model.size(of: item) == 0)
            }
        }
    }

    @ViewBuilder private var dockerControls: some View {
        if model.installedTools[.docker] == true && !model.isDockerRunning {
            if model.isStartingDocker {
                ProgressView().controlSize(.small)
                Text("Starting…")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Button("Start Docker") { model.startDocker() }
            }
        }
    }

    @ViewBuilder private var pickerControls: some View {
        let picked = model.pickedCount(for: item)
        if picked > 0 {
            Text("\(picked) selected")
                .font(.caption)
                .foregroundColor(.accentColor)
        }
        Button("Choose…") { model.activeSheet = .picker(item.id) }
    }
}
