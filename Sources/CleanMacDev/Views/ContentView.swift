import SwiftUI

/// The main window: header, the three sections, and the bottom bar.
struct ContentView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HeaderCard()
                ForEach(ItemGroup.allCases) { group in
                    GroupSection(group: group)
                }
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom) { BottomBar() }
        .sheet(item: $model.activeSheet) { sheet in
            sheetContent(for: sheet)
                .environmentObject(model)
        }
    }

    @ViewBuilder private func sheetContent(for sheet: SheetKind) -> some View {
        switch sheet {
        case .picker(let itemID):
            if let item = model.item(withID: itemID) {
                PickerSheet(item: item)
            }
        case .confirm:
            ConfirmSheet()
        case .result:
            ResultSheet()
        }
    }
}
