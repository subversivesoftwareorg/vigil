import SwiftUI

/// AI Activity mode: identifies file and process activity from AI systems,
/// making it easy to see AI's impact on the filesystem — what's being read,
/// written, downloaded, and by which AI tools.
struct AIActivityModeView: View {
    @Environment(MonitoringStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                summaryHeader
                if !activeAIProcesses.isEmpty {
                    aiProcessSection
                }
                aiFileActivitySection
                modelFileSection
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Active AI Processes

    private var activeAIProcesses: [(process: ProcessSnapshot, entry: AIProcessEntry, rate: ProcessIORate?)] {
        store.processes.compactMap { process in
            guard let entry = AIProcessCatalog.match(process.displayName) else { return nil }
            let rate = store.ioRates[process.pid]
            return (process, entry, rate)
        }
    }

    // MARK: - AI-Related File Events

    private var aiFileEvents: [(event: FileEvent, pattern: AIPathPattern)] {
        store.fileEvents.compactMap { event in
            guard let pattern = AIProcessCatalog.matchPath(event.path) else { return nil }
            return (event, pattern)
        }
    }

    // MARK: - Model Files

    private var modelFileEvents: [FileEvent] {
        store.fileEvents.filter { AIProcessCatalog.isModelFile($0.path) }
    }

    // MARK: - Summary Header

    @ViewBuilder
    private var summaryHeader: some View {
        let processCount = activeAIProcesses.count
        let fileCount = aiFileEvents.count
        let modelCount = modelFileEvents.count
        let totalIO = activeAIProcesses.reduce(0.0) { sum, item in
            sum + (item.rate.map { $0.readBytesPerSec + $0.writeBytesPerSec } ?? 0)
        }

        HStack(spacing: 24) {
            Image(systemName: "brain")
                .font(.system(size: 36))
                .foregroundStyle(.cyan)

            VStack(alignment: .leading, spacing: 4) {
                if processCount == 0 && fileCount == 0 && modelCount == 0 {
                    Text("No AI Activity Detected")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Vigil is watching for AI-related processes and file changes. Activity from tools like Claude Code, Copilot, Ollama, and others will appear here.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    Text("AI Activity")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(summaryText(processes: processCount, files: fileCount, models: modelCount, io: totalIO))
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private func summaryText(processes: Int, files: Int, models: Int, io: Double) -> String {
        var parts: [String] = []
        if processes > 0 {
            parts.append("\(processes) AI process\(processes == 1 ? "" : "es") running")
        }
        if files > 0 {
            parts.append("\(files) AI-related file event\(files == 1 ? "" : "s")")
        }
        if models > 0 {
            parts.append("\(models) model file\(models == 1 ? "" : "s") detected")
        }
        if io > 0 {
            let formatted = ByteCountFormatter.string(fromByteCount: Int64(io), countStyle: .memory)
            parts.append("\(formatted)/s total I/O")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - AI Process Section

    @ViewBuilder
    private var aiProcessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cpu")
                    .foregroundStyle(.cyan)
                Text("Running AI Processes")
                    .font(.headline)
            }

            ForEach(activeAIProcesses, id: \.process.pid) { item in
                AIProcessCard(process: item.process, entry: item.entry,
                              rate: item.rate, baseline: store.ioBaseline)
            }
        }
    }

    // MARK: - AI File Activity Section

    @ViewBuilder
    private var aiFileActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundStyle(.cyan)
                Text("AI File Activity")
                    .font(.headline)
                if !aiFileEvents.isEmpty {
                    Text("(\(aiFileEvents.count) events)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if aiFileEvents.isEmpty {
                Text("No AI-related file changes detected yet.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background, in: .rect(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
            } else {
                // Group by tool
                let grouped = Dictionary(grouping: aiFileEvents, by: { $0.pattern.tool })
                let sortedTools = grouped.sorted { $0.value.count > $1.value.count }

                ForEach(sortedTools, id: \.key) { tool, events in
                    AIToolFileCard(tool: tool, category: events.first?.pattern.category ?? .workspaceData,
                                   events: events.map(\.event))
                }
            }
        }
    }

    // MARK: - Model File Section

    @ViewBuilder
    private var modelFileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(.cyan)
                Text("Model Files")
                    .font(.headline)
            }

            Text("Files with known model extensions (.gguf, .safetensors, .bin, .onnx, etc.) that Vigil has seen being created or modified.")
                .font(.callout)
                .foregroundStyle(.secondary)

            if modelFileEvents.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.green)
                    Text("No model file downloads detected")
                        .font(.callout)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background, in: .rect(cornerRadius: 12))
                .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
            } else {
                ForEach(modelFileEvents) { event in
                    HStack {
                        Image(systemName: event.kind.systemImage)
                            .foregroundStyle(event.kind.color)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.displayName)
                                .fontWeight(.medium)
                            Text(shortenPath(event.directory))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if let tool = AIProcessCatalog.matchPath(event.path) {
                            Text(tool.tool)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.cyan.opacity(0.15), in: .capsule)
                                .foregroundStyle(.cyan)
                        }
                        Text(event.timestamp, style: .time)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(.background, in: .rect(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
                }
            }
        }
    }

    // MARK: - Helpers

    private func shortenPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}

// MARK: - AI Process Card

private struct AIProcessCard: View {
    let process: ProcessSnapshot
    let entry: AIProcessEntry
    let rate: ProcessIORate?
    let baseline: IOBaseline

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: entry.category.systemImage)
                    .foregroundStyle(.cyan)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(entry.displayName)
                            .fontWeight(.semibold)
                        Text("· \(entry.provider)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("· PID \(process.pid)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Text(entry.category.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // I/O data flow
            if let rate {
                HStack(spacing: 16) {
                    IOIndicator(
                        label: "Reading",
                        bytesPerSec: rate.readBytesPerSec,
                        explanation: "Data being read from disk (code files, context)"
                    )
                    IOIndicator(
                        label: "Writing",
                        bytesPerSec: rate.writeBytesPerSec,
                        explanation: "Data being written to disk (generated code, logs)"
                    )
                }

                // Memory footprint
                Text("Memory: \(ByteCountFormatter.string(fromByteCount: Int64(process.memoryBytes), countStyle: .memory))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(.background, in: .rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.cyan.opacity(0.2), lineWidth: 1)
        )
    }
}

private struct IOIndicator: View {
    let label: String
    let bytesPerSec: Double
    let explanation: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(formatRate(bytesPerSec))
                .font(.callout)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(bytesPerSec > 0 ? .cyan : .secondary)
        }
        .help(explanation)
    }

    private func formatRate(_ bps: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bps), countStyle: .memory) + "/s"
    }
}

// MARK: - AI Tool File Card

private struct AIToolFileCard: View {
    let tool: String
    let category: AIPathCategory
    let events: [FileEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(tool)
                    .fontWeight(.semibold)
                Text("· \(category.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(events.count) event\(events.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Show breakdown by kind
            let created = events.filter { $0.kind == .created }.count
            let modified = events.filter { $0.kind == .modified }.count
            let deleted = events.filter { $0.kind == .deleted }.count

            HStack(spacing: 12) {
                if created > 0 { kindLabel("Created", count: created, color: .green) }
                if modified > 0 { kindLabel("Modified", count: modified, color: .blue) }
                if deleted > 0 { kindLabel("Deleted", count: deleted, color: .red) }
            }

            // Recent files
            ForEach(events.suffix(3).reversed()) { event in
                HStack(spacing: 6) {
                    Image(systemName: event.kind.systemImage)
                        .foregroundStyle(event.kind.color)
                        .font(.caption)
                    Text(event.displayName)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                    Text(event.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(16)
        .background(.background, in: .rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
    }

    @ViewBuilder
    private func kindLabel(_ label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            Text("\(count)")
                .fontWeight(.medium)
            Text(label.lowercased())
        }
        .font(.caption)
        .foregroundStyle(color)
    }
}
