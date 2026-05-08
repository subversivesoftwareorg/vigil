import SwiftUI

/// Compact menu bar popover showing system health at a glance.
struct MenuBarView: View {
    @Environment(MonitoringStore.self) private var store
    @State private var result: HeuristicsResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Vigil")
                    .font(.headline)
                Spacer()
                if store.isMonitoring {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        Text("Monitoring")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            if let result {
                // Health score
                HStack(spacing: 12) {
                    healthRing(score: result.healthScore, level: result.healthLevel)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("System Health: \(result.healthLevel.rawValue)")
                            .font(.body)
                            .fontWeight(.medium)
                        Text("\(result.totalProcesses) processes (\(result.knownProcesses) recognized)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Findings summary
                if !result.findings.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(result.findings.count) finding\(result.findings.count == 1 ? "" : "s")")
                            .font(.caption)
                            .fontWeight(.medium)

                        ForEach(result.findings.prefix(3)) { finding in
                            HStack(spacing: 6) {
                                Image(systemName: finding.severity == .critical
                                      ? "exclamationmark.octagon.fill"
                                      : finding.severity == .warning
                                        ? "exclamationmark.triangle.fill"
                                        : "info.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(finding.severity == .critical ? .red
                                                     : finding.severity == .warning ? .orange : .blue)
                                Text(finding.title)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                        }
                        if result.findings.count > 3 {
                            Text("+ \(result.findings.count - 3) more...")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("All checks passed")
                            .font(.caption)
                    }
                }
            } else {
                Text("Analyzing...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Actions
            Button("Open Vigil") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.title.contains("Vigil") && !$0.title.contains("Help") }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }

            Button("Quit Vigil") {
                NSApp.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 280)
        .task(id: store.processes.count) {
            await refreshAnalysis()
        }
    }

    @MainActor
    private func refreshAnalysis() async {
        let engine = HeuristicsEngine(
            processes: store.processes,
            ioRates: store.ioRates,
            baseline: store.ioBaseline
        )
        result = engine.analyze()
    }

    @ViewBuilder
    private func healthRing(score: Int, level: HeuristicsResult.HealthLevel) -> some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 4)
                .frame(width: 40, height: 40)
            Circle()
                .trim(from: 0, to: Double(score) / 100.0)
                .stroke(healthColor(level), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 40, height: 40)
            Text("\(score)")
                .font(.caption)
                .fontWeight(.bold)
                .monospacedDigit()
        }
    }

    private func healthColor(_ level: HeuristicsResult.HealthLevel) -> Color {
        switch level {
        case .good: .green
        case .fair: .yellow
        case .concerning: .orange
        case .poor: .red
        }
    }
}
