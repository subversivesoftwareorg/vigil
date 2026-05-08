import SwiftUI

/// Inspector panel showing full detail for a selected process.
struct ProcessInspectorView: View {
    let process: ProcessSnapshot
    let rate: ProcessIORate?
    let anomalyScore: IOAnomalyScore?
    let knowledge: ProcessKnowledge?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                if let knowledge {
                    knowledgeSection(knowledge)
                }
                ioSection
                resourceSection
                identitySection
            }
            .padding()
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let knowledge {
                    Image(systemName: knowledge.category.systemImage)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                Text(process.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            if let path = process.path {
                Text(path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - Knowledge

    @ViewBuilder
    private func knowledgeSection(_ knowledge: ProcessKnowledge) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("About")
            Text(knowledge.description)
                .font(.body)
                .foregroundStyle(.primary)

            HStack(spacing: 16) {
                DetailChip(
                    label: "Category",
                    value: knowledge.category.rawValue,
                    systemImage: knowledge.category.systemImage
                )
                DetailChip(
                    label: "Expectation",
                    value: knowledge.expectation.rawValue,
                    systemImage: expectationImage(knowledge.expectation)
                )
            }
        }
    }

    // MARK: - I/O

    @ViewBuilder
    private var ioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Disk I/O")

            if let rate {
                HStack(spacing: 20) {
                    IOStat(label: "Read", bytesPerSec: rate.readBytesPerSec, color: .blue)
                    IOStat(label: "Write", bytesPerSec: rate.writeBytesPerSec, color: .orange)
                }

                HStack(spacing: 12) {
                    StatRow(label: "Total Read", value: formatBytes(process.diskBytesRead))
                    StatRow(label: "Total Written", value: formatBytes(process.diskBytesWritten))
                }
                .font(.caption)

                if let anomalyScore {
                    anomalyBadge(anomalyScore)
                }
            } else {
                Text("Waiting for data...")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Resources

    @ViewBuilder
    private var resourceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Resources")
            HStack(spacing: 12) {
                StatRow(label: "Memory",
                        value: ByteCountFormatter.string(fromByteCount: Int64(process.memoryBytes), countStyle: .memory))
                StatRow(label: "Footprint",
                        value: ByteCountFormatter.string(fromByteCount: Int64(process.physicalFootprint), countStyle: .memory))
            }
            HStack(spacing: 12) {
                StatRow(label: "CPU Time", value: formatCPUTime(process.cpuUsage))
                StatRow(label: "Energy", value: formatEnergy(process.energyNanojoules))
            }
            HStack(spacing: 12) {
                StatRow(label: "Page-ins", value: "\(process.pageins)")
                StatRow(label: "Logical Writes", value: formatBytes(process.logicalWrites))
            }
        }
        .font(.caption)
    }

    // MARK: - Identity

    @ViewBuilder
    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Identity")
            HStack(spacing: 12) {
                StatRow(label: "PID", value: "\(process.pid)")
                StatRow(label: "Parent PID", value: "\(process.parentPid)")
            }
            if process.name != process.displayName {
                StatRow(label: "Process Name", value: process.name)
            }
        }
        .font(.caption)
    }

    // MARK: - Anomaly Badge

    @ViewBuilder
    private func anomalyBadge(_ score: IOAnomalyScore) -> some View {
        HStack(spacing: 6) {
            Image(systemName: score.severity >= .anomalous
                  ? "exclamationmark.triangle.fill"
                  : "checkmark.circle.fill")
                .foregroundStyle(anomalyColor(score.severity))
            VStack(alignment: .leading, spacing: 2) {
                Text("Behavior: \(score.severity.rawValue)")
                    .fontWeight(.medium)
                if score.severity >= .unusual {
                    Text("Read: \(String(format: "%.1f", score.readZScore))σ — Write: \(String(format: "%.1f", score.writeZScore))σ from baseline")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text("Baseline: \(score.sampleCount) samples")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(anomalyColor(score.severity).opacity(0.1), in: .rect(cornerRadius: 6))
    }

    // MARK: - Helpers

    private func expectationImage(_ expectation: ProcessKnowledge.Expectation) -> String {
        switch expectation {
        case .alwaysRunning: "clock.fill"
        case .usuallyRunning: "clock"
        case .transient: "clock.arrow.circlepath"
        case .periodic: "calendar.circle"
        case .userLaunched: "person.circle"
        }
    }

    private func anomalyColor(_ severity: IOAnomalyScore.Severity) -> Color {
        switch severity {
        case .normal: .green
        case .unusual: .orange
        case .anomalous: .red
        case .extreme: .red
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private func formatCPUTime(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m \(secs)s"
        } else if minutes > 0 {
            return "\(minutes)m \(secs)s"
        }
        return String(format: "%.1fs", seconds)
    }

    private func formatEnergy(_ nanojoules: UInt64) -> String {
        let joules = Double(nanojoules) / 1_000_000_000.0
        if joules >= 1000 {
            return String(format: "%.1f kJ", joules / 1000)
        } else if joules >= 1 {
            return String(format: "%.1f J", joules)
        } else if nanojoules >= 1_000_000 {
            return String(format: "%.1f mJ", Double(nanojoules) / 1_000_000.0)
        }
        return "\(nanojoules) nJ"
    }
}

// MARK: - Supporting Views

private struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
    }
}

private struct DetailChip: View {
    let label: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.caption)
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding(6)
        .background(.quaternary, in: .rect(cornerRadius: 6))
    }
}

private struct IOStat: View {
    let label: String
    let bytesPerSec: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(format(bytesPerSec))
                .font(.title3)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(color)
        }
    }

    private func format(_ bps: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bps)) + "/s"
    }
}

private struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .foregroundStyle(.tertiary)
            Text(value)
                .fontWeight(.medium)
                .monospacedDigit()
        }
    }
}
