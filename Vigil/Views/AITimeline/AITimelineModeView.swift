import SwiftUI

/// Agent Timeline: chronological view of AI sessions across all tools.
struct AITimelineModeView: View {
    @Environment(MonitoringStore.self) private var store
    @State private var sessions: [(tool: String, session: AISessionLog)] = []
    @State private var selectedTool: String? = nil
    @State private var isLoading = true

    private var filteredSessions: [(tool: String, session: AISessionLog)] {
        let filtered = selectedTool == nil
            ? sessions
            : sessions.filter { $0.tool == selectedTool }
        return filtered.sorted { ($0.session.startedAt ?? .distantPast) > ($1.session.startedAt ?? .distantPast) }
    }

    private var toolNames: [String] {
        Set(sessions.map(\.tool)).sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            timelineHeader
            Divider()

            if isLoading {
                ProgressView("Loading sessions...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredSessions.isEmpty {
                ContentUnavailableView(
                    "No Sessions Found",
                    systemImage: "clock.arrow.2.circlepath",
                    description: Text(selectedTool != nil
                        ? "No sessions found for \(selectedTool!)."
                        : "Run an AI security scan to populate the timeline.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredSessions, id: \.session.id) { entry in
                            SessionTimelineCard(session: entry.session, toolName: entry.tool)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            var results: [(tool: String, session: AISessionLog)] = []
            for adapter in AIAdapterRegistry.adapters {
                let adapterSessions = adapter.parseSessions(projectFilter: nil)
                for session in adapterSessions {
                    results.append((tool: adapter.displayName, session: session))
                }
            }
            sessions = results
            isLoading = false
        }
    }

    @ViewBuilder
    private var timelineHeader: some View {
        HStack(spacing: 16) {
            Image(systemName: "clock.arrow.2.circlepath")
                .font(.title2)
                .foregroundStyle(.purple)
            VStack(alignment: .leading, spacing: 2) {
                Text("Agent Timeline")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("\(filteredSessions.count) session\(filteredSessions.count == 1 ? "" : "s")\(selectedTool != nil ? " from \(selectedTool!)" : " across all tools")")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            if toolNames.count > 1 {
                Picker("Tool", selection: $selectedTool) {
                    Text("All Tools").tag(nil as String?)
                    ForEach(toolNames, id: \.self) { name in
                        Text(name).tag(name as String?)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 160)
            }
        }
        .padding(16)
    }
}

// MARK: - Session Card

private struct SessionTimelineCard: View {
    let session: AISessionLog
    var toolName: String = ""

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(shortenPath(session.projectPath))
                            .font(.callout)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        if !toolName.isEmpty {
                            Text(toolName)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.purple.opacity(0.1), in: .capsule)
                                .foregroundStyle(.purple)
                        }
                    }
                    HStack(spacing: 8) {
                        if let start = session.startedAt {
                            Text(start, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(start, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let hours = session.durationHours {
                            Text(String(format: "%.1fh", hours))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                Spacer()

                HStack(spacing: 12) {
                    StatPill(label: "Turns", value: "\(session.totalTurns)")
                    StatPill(label: "Tools", value: "\(session.toolsUsed.count)")
                    StatPill(label: "Files", value: "\(Set(session.filesTouched.map(\.path)).count)")
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                Divider()
                expandedContent
            }
        }
        .padding(12)
        .background(.background, in: .rect(cornerRadius: 10))
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
    }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !session.toolsUsed.isEmpty {
                HStack(spacing: 4) {
                    Text("Tools:")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(session.toolsUsed.sorted { $0.value > $1.value }
                        .map { "\($0.key)(\($0.value))" }
                        .joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !session.modelsUsed.isEmpty {
                HStack(spacing: 4) {
                    Text("Models:")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(session.modelsUsed.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !session.bashCommands.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Commands (\(session.bashCommands.count)):")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    ForEach(session.bashCommands.prefix(5), id: \.self) { cmd in
                        Text(cmd)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if session.bashCommands.count > 5 {
                        Text("... and \(session.bashCommands.count - 5) more")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            if let branch = session.gitBranch {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.caption2)
                    Text(branch)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func shortenPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}

private struct StatPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}
