import SwiftUI

/// File Activity mode: what's happening on disk, with directory grouping
/// and process attribution where possible — answering "what's being touched?"
struct FileActivityModeView: View {
    @Environment(MonitoringStore.self) private var store
    @State private var groupByDirectory = true
    @State private var filterKind: FileEvent.Kind?

    var body: some View {
        VStack(spacing: 0) {
            summaryHeader
            Divider()
            eventContent
        }
        .toolbar {
            ToolbarItem {
                Picker("View", selection: $groupByDirectory) {
                    Label("By Directory", systemImage: "folder").tag(true)
                    Label("Timeline", systemImage: "clock").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            ToolbarItem {
                Menu {
                    Button("All Events") { filterKind = nil }
                    Divider()
                    ForEach([FileEvent.Kind.created, .modified, .deleted, .renamed, .metadataChanged], id: \.self) { kind in
                        Button {
                            filterKind = kind
                        } label: {
                            Label(kind.displayName, systemImage: kind.systemImage)
                        }
                    }
                } label: {
                    Label(filterKind?.displayName ?? "Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
    }

    // MARK: - Summary Header

    @ViewBuilder
    private var summaryHeader: some View {
        let events = filteredEvents
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 2) {
                Text("File Activity")
                    .font(.headline)
                Text("\(events.count) events\(filterKind != nil ? " (\(filterKind!.displayName.lowercased()))" : "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !store.fileEvents.isEmpty {
                HStack(spacing: 12) {
                    KindCount(kind: .created, events: store.fileEvents)
                    KindCount(kind: .modified, events: store.fileEvents)
                    KindCount(kind: .deleted, events: store.fileEvents)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Event Content

    @ViewBuilder
    private var eventContent: some View {
        let events = filteredEvents

        if events.isEmpty {
            ContentUnavailableView(
                "No File Events",
                systemImage: "doc.text.magnifyingglass",
                description: Text("Vigil is watching for file changes. Events will appear here as they happen.")
            )
        } else if groupByDirectory {
            directoryGroupedView(events)
        } else {
            timelineView(events)
        }
    }

    // MARK: - Directory Grouped View

    @ViewBuilder
    private func directoryGroupedView(_ events: [FileEvent]) -> some View {
        let groups = groupEventsByDirectory(events)

        List {
            ForEach(groups, id: \.directory) { group in
                Section {
                    ForEach(group.events.prefix(20)) { event in
                        eventRow(event, showDirectory: false)
                    }
                    if group.events.count > 20 {
                        Text("+ \(group.events.count - 20) more events")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                } header: {
                    HStack {
                        Image(systemName: "folder")
                            .foregroundStyle(.secondary)
                        Text(shortenPath(group.directory))
                            .font(.caption)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(group.events.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Text(directoryExplanation(group.directory))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    // MARK: - Timeline View

    @ViewBuilder
    private func timelineView(_ events: [FileEvent]) -> some View {
        List(events.suffix(500).reversed()) { event in
            eventRow(event, showDirectory: true)
        }
    }

    // MARK: - Event Row

    @ViewBuilder
    private func eventRow(_ event: FileEvent, showDirectory: Bool) -> some View {
        HStack {
            Image(systemName: event.kind.systemImage)
                .foregroundStyle(event.kind.color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.displayName)
                    .fontWeight(.medium)
                if showDirectory {
                    Text(shortenPath(event.directory))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Attribution hint
            if let attribution = attributeEvent(event) {
                Text(attribution)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: .capsule)
            }

            Text(event.timestamp, style: .time)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Filtering & Grouping

    private var filteredEvents: [FileEvent] {
        if let kind = filterKind {
            return store.fileEvents.filter { $0.kind == kind }
        }
        return store.fileEvents
    }

    private struct DirectoryGroup {
        let directory: String
        let events: [FileEvent]
    }

    private func groupEventsByDirectory(_ events: [FileEvent]) -> [DirectoryGroup] {
        var grouped: [String: [FileEvent]] = [:]
        for event in events {
            grouped[event.directory, default: []].append(event)
        }
        return grouped
            .map { DirectoryGroup(directory: $0.key, events: $0.value) }
            .sorted { $0.events.count > $1.events.count }
    }

    // MARK: - Path-Based Attribution

    /// Try to attribute a file event to a known process based on its path.
    private func attributeEvent(_ event: FileEvent) -> String? {
        let path = event.path.lowercased()

        // Common app paths
        let attributions: [(pattern: String, process: String)] = [
            ("/google/chrome", "Chrome"),
            ("/firefox", "Firefox"),
            ("/safari", "Safari"),
            ("/slack", "Slack"),
            ("/microsoft", "Microsoft"),
            ("/com.apple.mail", "Mail"),
            ("/xcode", "Xcode"),
            ("/docker", "Docker"),
            ("/spotify", "Spotify"),
            ("/discord", "Discord"),
            ("/com.apple.spotlight", "Spotlight"),
            ("/com.apple.bird", "iCloud"),
            ("/cloudd", "iCloud"),
            ("/com.apple.timemachine", "Time Machine"),
        ]

        for attr in attributions {
            if path.contains(attr.pattern) {
                return attr.process
            }
        }
        return nil
    }

    /// Explain what kind of activity a directory typically represents.
    private func directoryExplanation(_ dir: String) -> String {
        let lower = dir.lowercased()
        if lower.contains("/caches") { return "cache writes" }
        if lower.contains("/logs") { return "log files" }
        if lower.contains("/preferences") { return "preferences" }
        if lower.contains("/application support") { return "app data" }
        if lower.contains("/tmp") || lower.contains("/var/folders") { return "temporary files" }
        if lower.contains("/downloads") { return "downloads" }
        if lower.contains("/documents") { return "documents" }
        if lower.contains("/.git") { return "git operations" }
        if lower.contains("/build") || lower.contains("/deriveddata") { return "build output" }
        return ""
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

private struct KindCount: View {
    let kind: FileEvent.Kind
    let events: [FileEvent]

    var body: some View {
        let count = events.filter { $0.kind == kind }.count
        HStack(spacing: 4) {
            Image(systemName: kind.systemImage)
                .foregroundStyle(kind.color)
                .font(.caption)
            Text("\(count)")
                .font(.caption)
                .monospacedDigit()
        }
    }
}
