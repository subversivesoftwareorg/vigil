import SwiftUI

/// Overview mode: a glanceable dashboard showing system health, top concerns,
/// and summarized activity — answering "is my Mac healthy right now?"
struct OverviewModeView: View {
    @Environment(MonitoringStore.self) private var store
    @State private var result: HeuristicsResult?

    var body: some View {
        ScrollView {
            if store.processes.isEmpty {
                ContentUnavailableView(
                    "Starting Up",
                    systemImage: "square.grid.2x2",
                    description: Text("Gathering process information...")
                )
                .frame(maxHeight: .infinity)
            } else if let result {
                VStack(spacing: 24) {
                    healthHeader(result)
                    if !result.findings.isEmpty {
                        topConcerns(result)
                    }
                    HStack(alignment: .top, spacing: 16) {
                        processBreakdown(result)
                        fileActivitySummary
                    }
                }
                .padding(24)
            } else {
                ProgressView("Analyzing system...")
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    // MARK: - Health Header

    @ViewBuilder
    private func healthHeader(_ result: HeuristicsResult) -> some View {
        HStack(spacing: 24) {
            HealthRing(score: result.healthScore, level: result.healthLevel)

            VStack(alignment: .leading, spacing: 4) {
                Text("System Health: \(result.healthLevel.rawValue)")
                    .font(.title2)
                    .fontWeight(.bold)
                Text(healthExplanation(result))
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private func healthExplanation(_ result: HeuristicsResult) -> String {
        if result.findings.isEmpty {
            return "All checks passed. Your system looks healthy — \(result.totalProcesses) processes running, \(result.knownProcesses) recognized by Vigil."
        }
        let critical = result.findings.filter { $0.severity == .critical }.count
        let warnings = result.findings.filter { $0.severity == .warning }.count
        var parts: [String] = []
        if critical > 0 { parts.append("\(critical) critical") }
        if warnings > 0 { parts.append("\(warnings) warning\(warnings == 1 ? "" : "s")") }
        let info = result.findings.count - critical - warnings
        if info > 0 { parts.append("\(info) informational") }
        return "Vigil found \(result.findings.count) item\(result.findings.count == 1 ? "" : "s") worth noting: \(parts.joined(separator: ", "))."
    }

    // MARK: - Top Concerns

    @ViewBuilder
    private func topConcerns(_ result: HeuristicsResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text("Top Concerns")
                    .font(.headline)
                if result.findings.count > 3 {
                    Text("(\(result.findings.count) total — switch to History for all)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            ForEach(result.findings.prefix(3)) { finding in
                FindingCard(finding: finding)
            }
        }
    }

    // MARK: - Process Breakdown

    @ViewBuilder
    private func processBreakdown(_ result: HeuristicsResult) -> some View {
        let groups = categorizeProcesses()

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cpu")
                    .foregroundStyle(.green)
                Text("Processes")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                ProcessGroupRow(
                    label: "System Services",
                    count: groups.system,
                    systemImage: "gearshape.2",
                    color: .secondary
                )
                ProcessGroupRow(
                    label: "Apple Apps",
                    count: groups.appleApps,
                    systemImage: "apple.logo",
                    color: .secondary
                )
                ProcessGroupRow(
                    label: "Third-Party Apps",
                    count: groups.thirdParty,
                    systemImage: "app.badge",
                    color: .secondary
                )
                ProcessGroupRow(
                    label: "Unrecognized",
                    count: groups.unknown,
                    systemImage: "questionmark.circle",
                    color: groups.unknown > 50 ? .orange : .secondary,
                    annotation: unknownAnnotation(groups.unknown, result: result)
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: .rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
    }

    private func unknownAnnotation(_ count: Int, result: HeuristicsResult) -> String? {
        let flagged = result.findings.filter {
            $0.check == .unknownHighIO || $0.check == .phantomProcess
        }.count
        if flagged > 0 {
            return "\(flagged) flagged"
        }
        return nil
    }

    // MARK: - File Activity Summary

    @ViewBuilder
    private var fileActivitySummary: some View {
        let events = store.fileEvents
        let recent = events.suffix(500)

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundStyle(.purple)
                Text("File Activity")
                    .font(.headline)
            }

            if events.isEmpty {
                Text("No file events observed yet.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(events.count) events observed")
                        .font(.callout)

                    // Breakdown by kind
                    let created = recent.filter { $0.kind == .created }.count
                    let modified = recent.filter { $0.kind == .modified }.count
                    let deleted = recent.filter { $0.kind == .deleted }.count

                    HStack(spacing: 12) {
                        KindBadge(label: "Created", count: created, color: .green)
                        KindBadge(label: "Modified", count: modified, color: .blue)
                        KindBadge(label: "Deleted", count: deleted, color: .red)
                    }

                    // Hot directories
                    let hotDirs = topDirectories(from: Array(recent), limit: 3)
                    if !hotDirs.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Most active directories:")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            ForEach(hotDirs, id: \.dir) { entry in
                                HStack(spacing: 4) {
                                    Text(shortenPath(entry.dir))
                                        .font(.caption)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    Text("\(entry.count)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: .rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
    }

    // MARK: - Helpers

    private struct ProcessGroups {
        var system = 0
        var appleApps = 0
        var thirdParty = 0
        var unknown = 0
    }

    private func categorizeProcesses() -> ProcessGroups {
        var groups = ProcessGroups()
        for process in store.processes {
            guard let knowledge = ProcessDatabase.lookup(process.displayName) else {
                groups.unknown += 1
                continue
            }
            switch knowledge.category {
            case .kernel, .windowManager, .security, .storage, .networking,
                 .input, .diagnostics, .runtime, .utility:
                groups.system += 1
            case .appleApp, .cloud, .continuity, .appStore, .audio, .printing, .location:
                groups.appleApps += 1
            case .thirdParty, .developerTool:
                groups.thirdParty += 1
            }
        }
        return groups
    }

    private struct DirEntry {
        let dir: String
        let count: Int
    }

    private func topDirectories(from events: [FileEvent], limit: Int) -> [DirEntry] {
        var counts: [String: Int] = [:]
        for event in events {
            counts[event.directory, default: 0] += 1
        }
        return counts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { DirEntry(dir: $0.key, count: $0.value) }
    }

    private func shortenPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}

// MARK: - Supporting Views

private struct ProcessGroupRow: View {
    let label: String
    let count: Int
    let systemImage: String
    let color: Color
    var annotation: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
                .frame(width: 16)
            Text(label)
                .font(.callout)
            Spacer()
            if let annotation {
                Text(annotation)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Text("\(count)")
                .font(.callout)
                .fontWeight(.medium)
                .monospacedDigit()
        }
    }
}

private struct KindBadge: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.callout)
                .fontWeight(.semibold)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1), in: .rect(cornerRadius: 6))
    }
}
