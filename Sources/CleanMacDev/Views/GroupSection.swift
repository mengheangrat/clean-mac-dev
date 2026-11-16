import SwiftUI

/// A titled card of rows: Caches, Simulators & Emulators, or Tools.
struct GroupSection: View {
    @EnvironmentObject var model: AppModel
    let group: ItemGroup

    var body: some View {
        let rows = model.rows(in: group)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(group.title)
                    .font(.title3.weight(.semibold))
                Text(group.subtitle)
                    .font(.callout)
                    .foregroundColor(.secondary)
                Spacer()
                if group == .caches {
                    Button(model.allCachesSelected ? "Deselect all" : "Select all") {
                        model.toggleAllCaches()
                    }
                    .buttonStyle(.link)
                    .disabled(model.isBusy)
                }
            }
            Card {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { pair in
                        ItemRow(item: pair.element)
                        if pair.offset < rows.count - 1 {
                            Divider().padding(.leading, 106)
                        }
                    }
                }
            }
        }
    }
}
