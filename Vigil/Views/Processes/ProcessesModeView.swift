import SwiftUI

/// Processes mode: focused view of what's running, with knowledge annotations
/// and behavioral context — answering "what's running and should I worry?"
struct ProcessesModeView: View {
    @Environment(MonitoringStore.self) private var store
    @State private var selectedPid: Int32?
    @State private var showInspector = true
    @State private var sortOrder: SortOrder = .name

    enum SortOrder: String, CaseIterable {
        case name = "Name"
        case memory = "Memory"
        case io = "Disk I/O"
        case category = "Category"
    }

    var body: some View {
        HStack(spacing: 0) {
            processList
                .frame(minWidth: 500)

            if showInspector {
                Divider()
                inspectorContent
                    .frame(minWidth: 260, idealWidth: 320, maxWidth: 420)
            }
        }
        .toolbar {
            ToolbarItem {
                Picker("Sort", selection: $sortOrder) {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
            }
            ToolbarItem {
                Button {
                    withAnimation { showInspector.toggle() }
                } label: {
                    Label("Inspector", systemImage: "sidebar.trailing")
                }
                .help(showInspector ? "Hide Inspector" : "Show Inspector")
            }
        }
    }

    // MARK: - Process List

    @ViewBuilder
    private var processList: some View {
        List(sortedProcesses, selection: $selectedPid) { process in
            let knowledge = ProcessDatabase.lookup(process.displayName)
            let rate = store.ioRates[process.pid]
            let anomaly = rate.flatMap { store.ioBaseline.anomalyScore(for: $0) }

            HStack {
                // Category icon
                if let knowledge {
                    Image(systemName: knowledge.category.systemImage)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                } else {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(.tertiary)
                        .frame(width: 20)
                }

                // Name and context
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(process.displayName)
                            .fontWeight(.medium)
                        if let anomaly, anomaly.severity >= .unusual {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(anomaly.severity == .extreme ? .red : .orange)
                                .help(behaviorTooltip(anomaly, knowledge: knowledge))
                        }
                    }
                    Text(processSubtitle(process, knowledge: knowledge, anomaly: anomaly))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // I/O badges
                if let rate {
                    IOBadge(label: "R", bytesPerSec: rate.readBytesPerSec)
                    IOBadge(label: "W", bytesPerSec: rate.writeBytesPerSec)
                }

                // Memory
                Text(ByteCountFormatter.string(fromByteCount: Int64(process.memoryBytes), countStyle: .memory))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 80, alignment: .trailing)
            }
            .tag(process.pid)
        }
    }

    // MARK: - Inspector

    @ViewBuilder
    private var inspectorContent: some View {
        if let process = selectedProcess {
            let rate = store.ioRates[process.pid]
            ProcessInspectorView(
                process: process,
                rate: rate,
                anomalyScore: rate.flatMap { store.ioBaseline.anomalyScore(for: $0) },
                knowledge: ProcessDatabase.lookup(process.displayName)
            )
        } else {
            ContentUnavailableView(
                "Select a Process",
                systemImage: "cpu",
                description: Text("Click a process to see what it does, how it's behaving, and whether anything looks unusual.")
            )
        }
    }

    // MARK: - Sorting

    private var sortedProcesses: [ProcessSnapshot] {
        switch sortOrder {
        case .name:
            return store.processes.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        case .memory:
            return store.processes.sorted { $0.memoryBytes > $1.memoryBytes }
        case .io:
            return store.processes.sorted {
                let a = store.ioRates[$0.pid].map { $0.readBytesPerSec + $0.writeBytesPerSec } ?? 0
                let b = store.ioRates[$1.pid].map { $0.readBytesPerSec + $0.writeBytesPerSec } ?? 0
                return a > b
            }
        case .category:
            return store.processes.sorted {
                let catA = ProcessDatabase.lookup($0.displayName)?.category.rawValue ?? "zzz"
                let catB = ProcessDatabase.lookup($1.displayName)?.category.rawValue ?? "zzz"
                if catA != catB { return catA < catB }
                return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
        }
    }

    private var selectedProcess: ProcessSnapshot? {
        guard let pid = selectedPid else { return nil }
        return store.processes.first { $0.pid == pid }
    }

    // MARK: - Context Helpers

    /// Subtitle line under each process name — explains what it is and how it's behaving.
    private func processSubtitle(_ process: ProcessSnapshot, knowledge: ProcessKnowledge?, anomaly: IOAnomalyScore?) -> String {
        if let knowledge {
            if let anomaly, anomaly.severity >= .unusual {
                return behaviorNote(anomaly, knowledge: knowledge)
            }
            return knowledge.description
        }
        return process.path ?? "Unknown process"
    }

    /// A short behavioral note for processes with anomalous I/O.
    private func behaviorNote(_ score: IOAnomalyScore, knowledge: ProcessKnowledge) -> String {
        let metric = abs(score.readZScore) > abs(score.writeZScore) ? "reading" : "writing"
        let ratio = computeRatio(score)
        if let ratio {
            return "\(knowledge.category.rawValue) — \(metric) ~\(ratio)x more than usual"
        }
        return "\(knowledge.category.rawValue) — \(metric) more than usual"
    }

    /// Tooltip for the warning triangle badge.
    private func behaviorTooltip(_ score: IOAnomalyScore, knowledge: ProcessKnowledge?) -> String {
        let metric = abs(score.readZScore) > abs(score.writeZScore) ? "reading" : "writing"
        let ratio = computeRatio(score)
        let ratioText = ratio.map { " (~\($0)x normal)" } ?? ""
        let context = knowledge.map { " This is a \($0.category.rawValue.lowercased()) process." } ?? ""
        return "Currently \(metric) significantly more than baseline\(ratioText).\(context)"
    }

    private func computeRatio(_ score: IOAnomalyScore) -> Int? {
        let currentRead = score.baselineReadMean + score.readZScore * (score.baselineReadMean * 0.5)
        let currentWrite = score.baselineWriteMean + score.writeZScore * (score.baselineWriteMean * 0.5)

        if abs(score.readZScore) > abs(score.writeZScore) && score.baselineReadMean > 0 {
            let ratio = Int(currentRead / score.baselineReadMean)
            return ratio > 1 ? ratio : nil
        } else if score.baselineWriteMean > 0 {
            let ratio = Int(currentWrite / score.baselineWriteMean)
            return ratio > 1 ? ratio : nil
        }
        return nil
    }
}
