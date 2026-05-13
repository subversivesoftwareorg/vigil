import SwiftUI

/// History mode: current anomalies and behavioral trends over time, all in plain language
/// — answering "has anything changed?" Combines the Heuristics and Reporting engines.
struct HistoryModeView: View {
    @Environment(MonitoringStore.self) private var store
    @State private var reports: [BehaviorReport] = []
    @State private var isLoadingReports = false
    @State private var showPassedChecks = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let result = store.latestAnalysis {
                    healthHeader(result)
                    processCensus(result)

                    if !result.findings.isEmpty {
                        currentFindings(result)
                    }

                    passedChecksSection(result)

                    Divider()
                        .padding(.horizontal)

                    behaviorTrends
                } else {
                    ProgressView("Analyzing system...")
                        .frame(maxHeight: .infinity)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await loadReports()
        }
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await loadReports() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
    }

    @MainActor
    private func loadReports() async {
        guard let db = store.database else { return }
        isLoadingReports = true
        let reportEngine = ReportingEngine(database: db)
        reports = reportEngine.analyzeBehaviorChanges()
        isLoadingReports = false
    }

    // MARK: - Health Header

    @ViewBuilder
    private func healthHeader(_ result: HeuristicsResult) -> some View {
        HStack(spacing: 24) {
            HealthRing(score: result.healthScore, level: result.healthLevel)

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
        if result.findings.isEmpty {
            return "All checks passed. Your system looks healthy."
        }
        let critical = result.findings.filter { $0.severity == .critical }.count
        let warnings = result.findings.filter { $0.severity == .warning }.count
        var parts: [String] = []
        if critical > 0 { parts.append("\(critical) critical") }
        if warnings > 0 { parts.append("\(warnings) warning\(warnings == 1 ? "" : "s")") }
        let info = result.findings.count - critical - warnings
        if info > 0 { parts.append("\(info) informational") }
        return "\(result.findings.count) finding\(result.findings.count == 1 ? "" : "s"): \(parts.joined(separator: ", "))."
    }

    // MARK: - Census

    @ViewBuilder
    private func processCensus(_ result: HeuristicsResult) -> some View {
        HStack(spacing: 16) {
            CensusCard(label: "Total", value: "\(result.totalProcesses)",
                       systemImage: "cpu", color: .primary)
            CensusCard(label: "Recognized", value: "\(result.knownProcesses)",
                       systemImage: "checkmark.shield", color: .green)
            CensusCard(label: "Unrecognized", value: "\(result.unknownProcesses)",
                       systemImage: "questionmark.circle",
                       color: result.unknownProcesses > 50 ? .orange : .secondary)
        }
    }

    // MARK: - Current Findings

    @ViewBuilder
    private func currentFindings(_ result: HeuristicsResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text("Current Findings (\(result.findings.count))")
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

    // MARK: - Behavior Trends

    @ViewBuilder
    private var behaviorTrends: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.orange)
                Text("Behavioral Trends")
                    .font(.headline)
            }

            Text("Vigil compares each process's recent activity against its longer-term baseline to detect behavioral shifts.")
                .font(.callout)
                .foregroundStyle(.secondary)

            if isLoadingReports {
                ProgressView("Loading historical data...")
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if reports.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.title)
                        .foregroundStyle(.green)
                    Text("No behavioral changes detected")
                        .font(.body)
                        .fontWeight(.medium)
                    Text("All processes are behaving within their historical baselines. Trends will appear here as more data accumulates.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(.background, in: .rect(cornerRadius: 12))
                .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
            } else {
                Text("\(reports.count) process\(reports.count == 1 ? "" : "es") with behavioral changes:")
                    .font(.callout)

                ForEach(reports) { report in
                    TrendCard(report: report)
                }
            }
        }
    }
}

// MARK: - Trend Card

/// Shows a behavioral change report in plain language instead of z-scores.
private struct TrendCard: View {
    let report: BehaviorReport
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation { expanded.toggle() }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: severityIcon)
                        .foregroundStyle(severityColor)
                        .font(.title3)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text(report.processName)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            if let knowledge = report.knowledge {
                                Text("· \(knowledge.category.rawValue)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(trendSummary)
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

            if expanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()

                    if let knowledge = report.knowledge {
                        Text(knowledge.description)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(report.changes) { change in
                        changeRow(change)
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

    @ViewBuilder
    private func changeRow(_ change: BehaviorChange) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(changeDescription(change))
                .font(.callout)

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Text("Recent:")
                        .foregroundStyle(.tertiary)
                    Text(formatRate(max(change.recentReadMean, change.recentWriteMean)))
                }
                HStack(spacing: 4) {
                    Text("Baseline:")
                        .foregroundStyle(.tertiary)
                    Text(formatRate(max(change.baselineReadMean, change.baselineWriteMean)))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.quaternary, in: .rect(cornerRadius: 6))
    }

    /// Translate z-scores into plain language.
    private var trendSummary: String {
        guard let change = report.changes.first else { return "" }
        return changeDescription(change)
    }

    private func changeDescription(_ change: BehaviorChange) -> String {
        let metric = change.dominantMetric.capitalized
        let ratio = computeRatio(change)

        if let ratio, ratio >= 2 {
            return "\(metric) ~\(ratio)x \(change.direction == "increased" ? "more" : "less") than its \(change.baselineLabel) average"
        }
        return "\(metric) I/O has \(change.direction) compared to its \(change.baselineLabel) baseline"
    }

    private func computeRatio(_ change: BehaviorChange) -> Int? {
        let recent = abs(change.readZScore) > abs(change.writeZScore)
            ? change.recentReadMean : change.recentWriteMean
        let baseline = abs(change.readZScore) > abs(change.writeZScore)
            ? change.baselineReadMean : change.baselineWriteMean

        guard baseline > 0 else { return nil }
        let ratio = Int(recent / baseline)
        return ratio > 1 ? ratio : nil
    }

    private func formatRate(_ bytesPerSec: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytesPerSec), countStyle: .memory) + "/s"
    }

    private var severityIcon: String {
        switch report.maxSeverity {
        case .stable: "checkmark.circle"
        case .shifted: "arrow.up.right.circle.fill"
        case .changed: "exclamationmark.triangle.fill"
        case .dramatically: "exclamationmark.octagon.fill"
        }
    }

    private var severityColor: Color {
        switch report.maxSeverity {
        case .stable: .green
        case .shifted: .orange
        case .changed: .orange
        case .dramatically: .red
        }
    }
}
