import SwiftUI

/// Shown when cleaning finishes: how much was freed, plus any notes.
struct ResultSheet: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            Text("All clean!")
                .font(.title.weight(.bold))
            Text("Freed \((model.lastResult?.freed ?? 0).formattedBytes)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.accentColor)
            Text("\(model.disk.free.formattedBytes) is now free on your disk.")
                .foregroundColor(.secondary)

            if let issues = model.lastResult?.issues, !issues.isEmpty {
                DisclosureGroup("\(issues.count) note" + (issues.count == 1 ? "" : "s")) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(issues, id: \.self) { issue in
                            Text(issue)
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.top, 6)
            }

            Button("Done") { model.activeSheet = nil }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .padding(.top, 8)
        }
        .padding(32)
        .frame(width: 420)
    }
}
