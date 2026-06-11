import SwiftUI

/// Agent Timeline: chronological view of AI sessions across all tools.
struct AITimelineModeView: View {
    @Environment(MonitoringStore.self) private var store
    @State private var sessions: [AISessionLog] = []
    @State private var selectedTool: String? = nil
    @State private var isLoading = true

    private var filteredSessions: [AISessionLog] {
        let sorted = sessions.sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) }
        return sorted
    }

    private var toolNames: [String] {
        let names = Set(sessions.compactMap { session -> String? in
            AIAdapterRegistry.adapters.first { adapter in
                adapter.parseSessions(projectFilter: nil).contains { $0.id == session.id }
            }?.displayName
        })
        return names.sorted()
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
                    description: Text("Run an AI security scan to populate the timeline.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredSessions) { session in
                            SessionTimelineCard(session: session)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            sessions = AIAdapterRegistry.parseAllSessions()
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
                Text("\(sessions.count) session\(sessions.count == 1 ? "" : "s") across all tools")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
    }
}

// MARK: - Session Card

private struct SessionTimelineCard: View {
    let session: AISessionLog

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(shortenPath(session.projectPath))
                        .font(.callout)
                        .fontWeight(.medium)
                        .lineLimit(1)
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
