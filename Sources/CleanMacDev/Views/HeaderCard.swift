import SwiftUI

/// Disk usage ring, free space, and how much the scan found.
struct HeaderCard: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Card {
            HStack(spacing: 24) {
                DiskRing(fraction: model.disk.usedFraction, isLow: model.disk.isLow)
                    .frame(width: 118, height: 118)
                diskInfo
                Spacer()
                scanSummary
            }
            .padding(20)
        }
    }

    private var diskInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Macintosh HD")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("\(model.disk.free.formattedBytes) free")
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text("of \(model.disk.total.formattedBytes)")
                .foregroundColor(.secondary)
            if model.disk.isLow {
                Label("Your disk is almost full", systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundColor(.orange)
                    .padding(.top, 4)
            }
        }
    }

    private var scanSummary: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if model.isScanning && !model.hasScanned {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Scanning your Mac…").foregroundColor(.secondary)
                }
            } else {
                Text("Found")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(model.totalSize(in: .caches).formattedBytes)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.accentColor)
                Text("in caches")
                    .font(.callout)
                    .foregroundColor(.secondary)
                Text("+ \(model.totalSize(in: .devices).formattedBytes) in simulators & emulators")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Button { model.scan() } label: {
                Label(model.isScanning ? "Scanning…" : "Rescan", systemImage: "arrow.clockwise")
            }
            .disabled(model.isBusy)
            .padding(.top, 4)
            Button { model.activeSheet = .processes } label: {
                Label("Heavy processes", systemImage: "gauge.with.dots.needle.67percent")
            }
            Button { model.activeSheet = .security } label: {
                Label("Security check", systemImage: "checkmark.shield")
            }
            Button { model.activeSheet = .storage } label: {
                Label("Storage breakdown", systemImage: "internaldrive")
            }
        }
    }
}
