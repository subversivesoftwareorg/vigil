import SwiftUI

/// Heuristics mode: automated analysis with plain-English findings.
struct HeuristicsModeView: View {
    @Environment(MonitoringStore.self) private var store
    @State private var result: HeuristicsResult?
    @State private var showPassedChecks = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let result {
                    healthHeader(result)
                    processCensus(result)
                    if !result.findings.isEmpty {
                        findingsSection(result)
                    }
                    passedChecksSection(result)
                } else {
                    ProgressView("Analyzing system...")
                        .frame(maxHeight: .infinity)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: store.processes.count) {
            await refreshAnalysis()
        }
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await refreshAnalysis() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
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

    // MARK: - Health Header

    @ViewBuilder
    private func healthHeader(_ result: HeuristicsResult) -> some View {
        HStack(spacing: 24) {
            // Health ring
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 8)
                    .frame(width: 80, height: 80)
                Circle()
                    .trim(from: 0, to: Double(result.healthScore) / 100.0)
                    .stroke(healthColor(result.healthLevel), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 80, height: 80)
                VStack(spacing: 0) {
                    Text("\(result.healthScore)")
                        .font(.title)
                        .fontWeight(.bold)
                        .monospacedDigit()
                    Text("/ 100")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("System Health: \(result.healthLevel.rawValue)")
                    .font(.title2)
                    .fontWeight(.bold)
                Text(healthSummary(result))
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private func healthSummary(_ result: HeuristicsResult) -> String {
        let findingCount = result.findings.count
        if findingCount == 0 {
            return "All checks passed. Your system looks healthy."
        }
        let critical = result.findings.filter { $0.severity == .critical }.count
        let warnings = result.findings.filter { $0.severity == .warning }.count
        var parts: [String] = []
        if critical > 0 { parts.append("\(critical) critical") }
        if warnings > 0 { parts.append("\(warnings) warning\(warnings == 1 ? "" : "s")") }
        let info = findingCount - critical - warnings
        if info > 0 { parts.append("\(info) informational") }
        return "\(findingCount) finding\(findingCount == 1 ? "" : "s"): \(parts.joined(separator: ", "))."
    }

    // MARK: - Process Census

    @ViewBuilder
    private func processCensus(_ result: HeuristicsResult) -> some View {
        HStack(spacing: 16) {
            CensusCard(
                label: "Total",
                value: "\(result.totalProcesses)",
                systemImage: "cpu",
                color: .primary
            )
            CensusCard(
                label: "Recognized",
                value: "\(result.knownProcesses)",
                systemImage: "checkmark.shield",
                color: .green
            )
            CensusCard(
                label: "Unrecognized",
                value: "\(result.unknownProcesses)",
                systemImage: "questionmark.circle",
                color: result.unknownProcesses > 50 ? .orange : .secondary
            )
        }
    }

    // MARK: - Findings

    @ViewBuilder
    private func findingsSection(_ result: HeuristicsResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text("Attention (\(result.findings.count))")
                    .font(.headline)
            }

            ForEach(result.findings) { finding in
                FindingCard(finding: finding)
            }
        }
    }

    // MARK: - Passed Checks

    @ViewBuilder
    private func passedChecksSection(_ result: HeuristicsResult) -> some View {
        if !result.passedChecks.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation { showPassedChecks.toggle() }
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.green)
                        Text("All Clear (\(result.passedChecks.count))")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: showPassedChecks ? "chevron.up" : "chevron.down")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if showPassedChecks {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(result.passedChecks) { check in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                Text(check.message)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.leading, 28)
                }
            }
            .padding(16)
            .background(.background, in: .rect(cornerRadius: 12))
            .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
        }
    }

    // MARK: - Helpers

    private func healthColor(_ level: HeuristicsResult.HealthLevel) -> Color {
        switch level {
        case .good: .green
        case .fair: .yellow
        case .concerning: .orange
        case .poor: .red
        }
    }
}

// MARK: - Census Card

private struct CensusCard: View {
    let label: String
    let value: String
    let systemImage: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.background, in: .rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
    }
}

// MARK: - Finding Card

private struct FindingCard: View {
    let finding: Finding
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            Button {
                withAnimation { expanded.toggle() }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: severityIcon)
                        .foregroundStyle(severityColor)
                        .font(.title3)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(finding.title)
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        Text(finding.description)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)

            // Expanded detail
            if expanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    HStack(spacing: 4) {
                        Image(systemName: "lightbulb")
                            .foregroundStyle(.yellow)
                        Text("Recommendation")
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                    Text(finding.recommendation)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    if let pid = finding.affectedPid {
                        HStack {
                            Text("Process: \(finding.affectedProcess)")
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text("PID \(pid)")
                        }
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    }
                }
                .padding(.leading, 34)
            }
        }
        .padding(16)
        .background(severityColor.opacity(0.04), in: .rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(severityColor.opacity(0.15), lineWidth: 1)
        )
    }

    private var severityIcon: String {
        switch finding.severity {
        case .critical: "exclamationmark.octagon.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        }
    }

    private var severityColor: Color {
        switch finding.severity {
        case .critical: .red
        case .warning: .orange
        case .info: .blue
        }
    }
}
