import SwiftUI

/// File Sharing mode: surfaces activity from cloud sync, backup, and file transfer
/// tools — answering "what's being synced, backed up, or shared?"
struct FileSharingModeView: View {
    @Environment(MonitoringStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                summaryHeader
                if !activeProcesses.isEmpty {
                    processSection
                }
                fileActivitySection
                categoryBreakdown
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Active File Sharing Processes

    private var activeProcesses: [(process: ProcessSnapshot, entry: FileSharingProcessEntry, rate: ProcessIORate?)] {
        store.processes.compactMap { process in
            guard let entry = FileSharingCatalog.match(process.displayName) else { return nil }
            let rate = store.ioRates[process.pid]
            return (process, entry, rate)
        }
    }

    // MARK: - File Sharing File Events

    private var sharingFileEvents: [(event: FileEvent, pattern: FileSharingPathPattern)] {
        store.fileEvents.compactMap { event in
            guard let pattern = FileSharingCatalog.matchPath(event.path) else { return nil }
            return (event, pattern)
        }
    }

    // MARK: - Summary Header

    @ViewBuilder
    private var summaryHeader: some View {
        let processCount = activeProcesses.count
        let fileCount = sharingFileEvents.count
        let totalIO = activeProcesses.reduce(0.0) { sum, item in
            sum + (item.rate.map { $0.readBytesPerSec + $0.writeBytesPerSec } ?? 0)
        }

        HStack(spacing: 24) {
            Image(systemName: "icloud.and.arrow.up.and.arrow.down")
                .font(.system(size: 36))
                .foregroundStyle(.indigo)

            VStack(alignment: .leading, spacing: 4) {
                if processCount == 0 && fileCount == 0 {
                    Text("No File Sharing Activity Detected")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Vigil is watching for cloud sync, backup, and file transfer tools. Activity from Dropbox, OneDrive, iCloud Drive, Time Machine, and others will appear here.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    Text("File Sharing Activity")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(summaryText(processes: processCount, files: fileCount, io: totalIO))
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

    private func summaryText(processes: Int, files: Int, io: Double) -> String {
        var parts: [String] = []
        if processes > 0 {
            parts.append("\(processes) sync process\(processes == 1 ? "" : "es") running")
        }
        if files > 0 {
            parts.append("\(files) file event\(files == 1 ? "" : "s") in sync directories")
        }
        if io > 0 {
            let formatted = ByteCountFormatter.string(fromByteCount: Int64(io), countStyle: .memory)
            parts.append("\(formatted)/s total I/O")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Process Section

    @ViewBuilder
    private var processSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.indigo)
                Text("Running Sync & Backup Processes")
                    .font(.headline)
            }

            // Group by category
            let grouped = Dictionary(grouping: activeProcesses, by: { $0.entry.category })
            let sortedCategories: [FileSharingCategory] = [.cloudSync, .backup, .transfer]

            ForEach(sortedCategories, id: \.self) { category in
                if let items = grouped[category], !items.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: category.systemImage)
                                .foregroundStyle(.secondary)
                            Text(category.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                        }

                        ForEach(items, id: \.process.pid) { item in
                            SyncProcessCard(process: item.process, entry: item.entry, rate: item.rate)
                        }
                    }
                }
            }
        }
    }

    // MARK: - File Activity Section

    @ViewBuilder
    private var fileActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundStyle(.indigo)
                Text("Sync Directory Activity")
                    .font(.headline)
                if !sharingFileEvents.isEmpty {
                    Text("(\(sharingFileEvents.count) events)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if sharingFileEvents.isEmpty {
                Text("No file changes detected in sync directories yet.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background, in: .rect(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
            } else {
                let grouped = Dictionary(grouping: sharingFileEvents, by: { $0.pattern.tool })
                let sortedTools = grouped.sorted { $0.value.count > $1.value.count }

                ForEach(sortedTools, id: \.key) { tool, items in
                    SyncToolFileCard(tool: tool,
                                     category: items.first?.pattern.category ?? .cloudSync,
                                     events: items.map(\.event))
                }
            }
        }
    }

    // MARK: - Category Breakdown

    @ViewBuilder
    private var categoryBreakdown: some View {
        let syncEvents = sharingFileEvents.filter { $0.pattern.category == .cloudSync }
        let backupEvents = sharingFileEvents.filter { $0.pattern.category == .backup }

        if !syncEvents.isEmpty || !backupEvents.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "chart.pie")
                        .foregroundStyle(.indigo)
                    Text("Activity Breakdown")
                        .font(.headline)
                }

                HStack(spacing: 16) {
                    BreakdownCard(
                        label: "Cloud Sync",
                        count: syncEvents.count,
                        systemImage: "icloud",
                        color: .blue,
                        detail: syncDetail(syncEvents)
                    )
                    BreakdownCard(
                        label: "Backup",
                        count: backupEvents.count,
                        systemImage: "clock.arrow.2.circlepath",
                        color: .orange,
                        detail: nil
                    )
                }
            }
        }
    }

    private func syncDetail(_ events: [(event: FileEvent, pattern: FileSharingPathPattern)]) -> String? {
        let created = events.filter { $0.event.kind == .created }.count
        let modified = events.filter { $0.event.kind == .modified }.count
        let deleted = events.filter { $0.event.kind == .deleted }.count
        var parts: [String] = []
        if created > 0 { parts.append("\(created) new") }
        if modified > 0 { parts.append("\(modified) changed") }
        if deleted > 0 { parts.append("\(deleted) removed") }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}

// MARK: - Sync Process Card

private struct SyncProcessCard: View {
    let process: ProcessSnapshot
    let entry: FileSharingProcessEntry
    let rate: ProcessIORate?

    var body: some View {
        HStack {
            Image(systemName: entry.category.systemImage)
                .foregroundStyle(.indigo)
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

                if let rate {
                    HStack(spacing: 12) {
                        ioLabel("Read", bytesPerSec: rate.readBytesPerSec)
                        ioLabel("Write", bytesPerSec: rate.writeBytesPerSec)
                        Text("Memory: \(ByteCountFormatter.string(fromByteCount: Int64(process.memoryBytes), countStyle: .memory))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer()
        }
        .padding(12)
        .background(.background, in: .rect(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.indigo.opacity(0.15), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func ioLabel(_ label: String, bytesPerSec: Double) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .foregroundStyle(.tertiary)
            Text(ByteCountFormatter.string(fromByteCount: Int64(bytesPerSec), countStyle: .memory) + "/s")
                .fontWeight(.medium)
                .foregroundStyle(bytesPerSec > 0 ? .indigo : .secondary)
        }
        .font(.caption)
        .monospacedDigit()
    }
}

// MARK: - Sync Tool File Card

private struct SyncToolFileCard: View {
    let tool: String
    let category: FileSharingCategory
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

            let created = events.filter { $0.kind == .created }.count
            let modified = events.filter { $0.kind == .modified }.count
            let deleted = events.filter { $0.kind == .deleted }.count

            HStack(spacing: 12) {
                if created > 0 { kindLabel("Created", count: created, color: .green) }
                if modified > 0 { kindLabel("Modified", count: modified, color: .blue) }
                if deleted > 0 { kindLabel("Deleted", count: deleted, color: .red) }
            }

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

// MARK: - Breakdown Card

private struct BreakdownCard: View {
    let label: String
    let count: Int
    let systemImage: String
    let color: Color
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .foregroundStyle(color)
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            Text("\(count) event\(count == 1 ? "" : "s")")
                .font(.title3)
                .fontWeight(.bold)
                .monospacedDigit()
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background, in: .rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
    }
}
