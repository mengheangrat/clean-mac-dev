import SwiftUI

/// Results of the security check: device protections, network settings, and suspicious programs.
struct SecuritySheet: View {
    @EnvironmentObject var model: AppModel
    @State private var findings: [SecurityFinding]?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                IconTile(symbol: "checkmark.shield", color: .green, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Security check")
                        .font(.title2.weight(.bold))
                    Text("Signs of malware on this Mac or its network.")
                        .foregroundColor(.secondary)
                }
            }

            Card {
                if let findings {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(findings) { finding in
                                row(for: finding)
                                Divider()
                            }
                        }
                    }
                    .frame(height: 360)
                } else {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Checking…").foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 360)
                }
            }

            HStack {
                Text("Not an antivirus scan. It checks what malware usually changes.")
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
            findings = await Task.detached { SecurityCheck.run() }.value
        }
    }

    private func row(for finding: SecurityFinding) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: finding.isWarning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundColor(finding.isWarning ? .orange : .green)
            VStack(alignment: .leading, spacing: 2) {
                Text(finding.title).font(.headline)
                Text(finding.detail)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
