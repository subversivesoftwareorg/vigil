import SwiftUI

/// Expert mode: detailed process trees, file activity streams, raw data.
struct ExpertModeView: View {
    @Environment(MonitoringStore.self) private var store
    @State private var selectedPid: Int32?
    @State private var showInspector = true

    var body: some View {
        HStack(spacing: 0) {
            // Process list
            List(store.processes, selection: $selectedPid) { process in
                let knowledge = ProcessDatabase.lookup(process.displayName)
                let rate = store.ioRates[process.pid]
                HStack {
                    if let knowledge {
                        Image(systemName: knowledge.category.systemImage)
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                    }
                    VStack(alignment: .leading) {
                        HStack(spacing: 4) {
                            Text(process.displayName)
                                .fontWeight(.medium)
                            if let rate, let score = store.ioBaseline.anomalyScore(for: rate),
                               score.severity >= .unusual {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(score.severity == .extreme ? .red : .orange)
                                    .help("I/O \(score.severity.rawValue): \(String(format: "%.1f", score.maxZScore))σ from baseline")
                            }
                        }
                        if let knowledge {
                            Text(knowledge.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    if let rate {
                        IOBadge(label: "R", bytesPerSec: rate.readBytesPerSec)
                        IOBadge(label: "W", bytesPerSec: rate.writeBytesPerSec)
                    }
                    Text("PID \(process.pid)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Text(ByteCountFormatter.string(fromByteCount: Int64(process.memoryBytes), countStyle: .memory))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 80, alignment: .trailing)
                }
                .tag(process.pid)
            }
            .frame(minWidth: 500)

            Divider()

            // File events
            List(store.fileEvents.suffix(200).reversed()) { event in
                HStack {
                    Image(systemName: event.kind.systemImage)
                        .foregroundStyle(event.kind.color)
                    VStack(alignment: .leading) {
                        Text(event.displayName)
                            .fontWeight(.medium)
                        Text(event.directory)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(event.timestamp, style: .time)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(minWidth: 300)

            // Inspector pane
            if showInspector {
                Divider()
                inspectorContent
                    .frame(minWidth: 260, idealWidth: 300, maxWidth: 400)
            }
        }
        .toolbar {
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

    // MARK: - Inspector Content

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
                description: Text("Click a process in the list to inspect its details.")
            )
        }
    }

    private var selectedProcess: ProcessSnapshot? {
        guard let pid = selectedPid else { return nil }
        return store.processes.first { $0.pid == pid }
    }
}

// MARK: - FileEvent Display Helpers

extension FileEvent.Kind {
    var systemImage: String {
        switch self {
        case .created: "plus.circle.fill"
        case .modified: "pencil.circle.fill"
        case .deleted: "minus.circle.fill"
        case .renamed: "arrow.triangle.swap"
        case .metadataChanged: "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .created: .green
        case .modified: .blue
        case .deleted: .red
        case .renamed: .orange
        case .metadataChanged: .purple
        }
    }
}
