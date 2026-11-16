import SwiftUI

/// Round checkbox with on, off and mixed states.
struct CheckBox: View {
    let state: CheckState
    let action: () -> Void
    @Environment(\.isEnabled) var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: symbolName)
                .font(.system(size: 20))
                .foregroundColor(state == .off ? Color.secondary.opacity(0.7) : Color.accentColor)
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.35)
    }

    private var symbolName: String {
        switch state {
        case .on: return "checkmark.circle.fill"
        case .mixed: return "minus.circle.fill"
        case .off: return "circle"
        }
    }
}

/// Colored rounded square with a white SF Symbol, like a settings icon.
struct IconTile: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 34

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.26)
            .fill(color.gradient)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundColor(.white)
            )
    }
}

/// Thin horizontal bar showing a size relative to the biggest one.
struct SizeBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(color.gradient)
                    .frame(width: max(4, geometry.size.width * CGFloat(min(max(fraction, 0), 1))))
            }
        }
        .frame(height: 6)
    }
}

/// Ring chart of how full the disk is.
struct DiskRing: View {
    let fraction: Double
    let isLow: Bool

    var body: some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.08), lineWidth: 14)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(fraction, 0), 1)))
                .stroke(
                    AngularGradient(gradient: Gradient(colors: isLow ? [.orange, .red] : [.teal, .blue]),
                                    center: .center),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.8), value: fraction)
            VStack(spacing: 0) {
                Text("\(Int((fraction * 100).rounded()))%")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text("used")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// Rounded panel that groups rows.
struct Card<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.07)))
    }
}

/// Status icon shown on a row while cleaning.
struct RunStateIcon: View {
    let state: RunState

    var body: some View {
        switch state {
        case .waiting:
            Image(systemName: "clock").foregroundColor(.secondary)
        case .working:
            ProgressView().controlSize(.small)
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
        }
    }
}

/// Size text aligned in a fixed-width column.
struct SizeText: View {
    let text: String
    var isMuted = false

    var body: some View {
        Text(text)
            .font(.callout.weight(.medium))
            .monospacedDigit()
            .foregroundColor(isMuted ? Color.secondary : Color.primary)
            .frame(minWidth: 64, alignment: .trailing)
    }
}
