import SwiftUI

/// A compact badge showing I/O throughput (e.g., "R 1.2 MB/s").
struct IOBadge: View {
    let label: String
    let bytesPerSec: Double

    var body: some View {
        if bytesPerSec >= 1 {
            HStack(spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(label == "R" ? .blue : .orange)
                Text(Self.format(bytesPerSec))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(.quaternary, in: .capsule)
        }
    }

    private static func format(_ bytesPerSec: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: Int64(bytesPerSec)) + "/s"
    }
}
