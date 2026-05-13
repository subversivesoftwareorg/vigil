import SwiftUI

/// Reusable circular health score indicator.
struct HealthRing: View {
    let score: Int
    let level: HeuristicsResult.HealthLevel
    var size: CGFloat = 80
    var lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: Double(score) / 100.0)
                .stroke(level.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(size >= 60 ? .title : .caption)
                    .fontWeight(.bold)
                    .monospacedDigit()
                if size >= 60 {
                    Text("/ 100")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Health Level Color

extension HeuristicsResult.HealthLevel {
    var color: Color {
        switch self {
        case .good: .green
        case .fair: .yellow
        case .concerning: .orange
        case .poor: .red
        }
    }
}
