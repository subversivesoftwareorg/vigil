import SwiftUI

/// Reporting mode: highlights processes with behavioral changes across time windows.
struct ReportingModeView: View {
    @Environment(MonitoringStore.self) private var store
    @State private var reports: [BehaviorReport] = []
    @State private var selectedReport: BehaviorReport?
    @State private var isLoading = false

    var body: some View {
        HSplitView {
            // Report list
            VStack(alignment: .leading, spacing: 0) {
                reportHeader
                if isLoading {
                    ProgressView("Analyzing behavior...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if reports.isEmpty {
                    ContentUnavailableView(
                        "No Behavioral Changes Detected",
                        systemImage: "checkmark.circle",
                        description: Text("All processes are behaving within their historical baselines. Check back as more data accumulates.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(reports, selection: Binding(
                        get: { selectedReport?.processName },
                        set: { name in selectedReport = reports.first { $0.processName == name } }
                    )) { report in
                        ReportRow(report: report)
                            .tag(report.processName)
                    }
                }
            }
            .frame(minWidth: 450)

            // Detail pane
            if let report = selectedReport {
                ReportDetailView(report: report)
                    .frame(minWidth: 350)
            } else {
                ContentUnavailableView(
                    "Select a Report",
                    systemImage: "chart.bar",
                    description: Text("Click a process to see its behavioral analysis.")
                )
                .frame(minWidth: 350)
            }
        }
        .task {
            await loadReports()
        }
    }

    private var reportHeader: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Behavior Reports")
                    .font(.headline)
                Text("\(reports.count) processes with changes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await loadReports() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
        .padding()
    }

    private func loadReports() async {
        guard let db = store.database else { return }
        isLoading = true
        let engine = ReportingEngine(database: db)
        reports = engine.analyzeBehaviorChanges()
        isLoading = false
    }
}

// MARK: - Report Row

private struct ReportRow: View {
    let report: BehaviorReport

    var body: some View {
        HStack(spacing: 10) {
            severityIcon
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(report.processName)
                        .fontWeight(.medium)
                    if let knowledge = report.knowledge {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(knowledge.category.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(changeSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            timeWindowBadges
        }
    }

    @ViewBuilder
    private var severityIcon: some View {
        let (image, color) = severityDisplay(report.maxSeverity)
        Image(systemName: image)
            .foregroundStyle(color)
            .font(.title3)
    }

    private var changeSummary: String {
        guard let change = report.changes.first else { return "" }
        return "\(change.dominantMetric.capitalized) \(change.direction) over \(change.recentLabel)"
    }

    @ViewBuilder
    private var timeWindowBadges: some View {
        HStack(spacing: 4) {
            ForEach(report.changes, id: \.comparison.rawValue) { change in
                Text(shortLabel(change.comparison))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(severityDisplay(change.severity).color.opacity(0.15), in: .capsule)
                    .foregroundStyle(severityDisplay(change.severity).color)
            }
        }
    }

    private func shortLabel(_ comparison: BehaviorChange.Comparison) -> String {
        switch comparison {
        case .shortTerm: "7d"
        case .mediumTerm: "30d"
        case .longTerm: "90d"
        }
    }

    private func severityDisplay(_ severity: BehaviorChange.Severity) -> (image: String, color: Color) {
        switch severity {
        case .stable: ("checkmark.circle", .green)
        case .shifted: ("arrow.up.right.circle.fill", .orange)
        case .changed: ("exclamationmark.triangle.fill", .orange)
        case .dramatically: ("exclamationmark.octagon.fill", .red)
        }
    }
}

// MARK: - Report Detail

private struct ReportDetailView: View {
    let report: BehaviorReport

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.processName)
                        .font(.title2)
                        .fontWeight(.bold)
                    if let knowledge = report.knowledge {
                        Text(knowledge.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }

                // Window overview
                windowOverview

                // Changes
                ForEach(report.changes) { change in
                    ChangeCard(change: change)
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private var windowOverview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("I/O Across Time Windows")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Window").fontWeight(.semibold)
                    Text("Avg Read/s").fontWeight(.semibold)
                    Text("Avg Write/s").fontWeight(.semibold)
                    Text("Samples").fontWeight(.semibold)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                ForEach(TimePeriod.allCases) { period in
                    let stats = report.windows.stats(for: period)
                    GridRow {
                        Text(period.rawValue)
                            .fontWeight(.medium)
                        Text(stats.hasData ? formatRate(stats.readStats.mean) : "—")
                            .monospacedDigit()
                        Text(stats.hasData ? formatRate(stats.writeStats.mean) : "—")
                            .monospacedDigit()
                        Text(stats.hasData ? "\(stats.sampleCount)" : "—")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
            }
        }
        .padding()
        .background(.quaternary, in: .rect(cornerRadius: 8))
    }

    private func formatRate(_ bytesPerSec: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytesPerSec), countStyle: .memory) + "/s"
    }
}

// MARK: - Change Card

private struct ChangeCard: View {
    let change: BehaviorChange

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: change.severity >= .changed
                      ? "exclamationmark.triangle.fill"
                      : "arrow.up.right.circle.fill")
                    .foregroundStyle(change.severity >= .changed ? .red : .orange)
                Text("\(change.comparison.rawValue) Change")
                    .fontWeight(.semibold)
                Spacer()
                Text(change.severity.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(change.severity >= .changed ? Color.red.opacity(0.15) : Color.orange.opacity(0.15), in: .capsule)
            }

            Text("\(change.dominantMetric.capitalized) I/O has \(change.direction) compared to the \(change.baselineLabel) baseline.")
                .font(.body)

            HStack(spacing: 24) {
                VStack(alignment: .leading) {
                    Text("Recent (\(change.recentLabel))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    HStack(spacing: 8) {
                        Label(formatRate(change.recentReadMean), systemImage: "arrow.down.circle")
                            .font(.caption)
                        Label(formatRate(change.recentWriteMean), systemImage: "arrow.up.circle")
                            .font(.caption)
                    }
                }
                VStack(alignment: .leading) {
                    Text("Baseline (\(change.baselineLabel))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    HStack(spacing: 8) {
                        Label(formatRate(change.baselineReadMean), systemImage: "arrow.down.circle")
                            .font(.caption)
                        Label(formatRate(change.baselineWriteMean), systemImage: "arrow.up.circle")
                            .font(.caption)
                    }
                }
            }

            Text("Deviation: \(String(format: "%.1f", change.maxZScore))σ from baseline")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.background, in: .rect(cornerRadius: 8))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    private func formatRate(_ bytesPerSec: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytesPerSec), countStyle: .memory) + "/s"
    }
}
