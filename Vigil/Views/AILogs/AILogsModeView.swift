import SwiftUI

struct AILogsModeView: View {
    @State private var sessions: [AISessionLog] = []
    @State private var isLoading = true
    @State private var projectFilter: String = "All"
    @State private var searchText = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                summaryHeader
                if !sessions.isEmpty {
                    toolbar
                }
                sessionList
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            sessions = AISessionLogParser.parseAll()
            isLoading = false
        }
    }

    // MARK: - Derived Data

    private var projectNames: [String] {
        let names = Set(sessions.map { abbreviatedProject($0.projectPath) })
        return ["All"] + names.sorted()
    }

    private var filteredSessions: [AISessionLog] {
        var result = sessions

        if projectFilter != "All" {
            result = result.filter { abbreviatedProject($0.projectPath) == projectFilter }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { session in
                session.projectPath.lowercased().contains(query)
                || session.bashCommands.contains { $0.lowercased().contains(query) }
                || session.filesTouched.contains { $0.path.lowercased().contains(query) }
                || session.modelsUsed.contains { $0.lowercased().contains(query) }
            }
        }

        return result.sorted {
            ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast)
        }
    }

    private var totalTokens: Int { sessions.reduce(0) { $0 + $1.tokens.total } }
    private var totalCommands: Int { sessions.reduce(0) { $0 + $1.bashCommands.count } }
    private var totalFiles: Int {
        let paths = Set(sessions.flatMap { $0.filesTouched.map(\.path) })
        return paths.count
    }

    // MARK: - Summary Header

    @ViewBuilder
    private var summaryHeader: some View {
        HStack(spacing: 24) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.indigo)

            VStack(alignment: .leading, spacing: 4) {
                if isLoading {
                    Text("Scanning Session Logs...")
                        .font(.title2)
                        .fontWeight(.bold)
                    ProgressView()
                        .controlSize(.small)
                } else if sessions.isEmpty {
                    Text("No AI Session Logs Found")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Claude Code session logs are stored in ~/.claude/projects/. Start a Claude Code session and logs will appear here.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(sessions.count) Sessions")
                        .font(.title2)
                        .fontWeight(.bold)
                    HStack(spacing: 16) {
                        StatPill(label: "Projects", value: "\(projectNames.count - 1)")
                        StatPill(label: "Tokens", value: formatTokens(totalTokens))
                        StatPill(label: "Commands", value: "\(totalCommands)")
                        StatPill(label: "Files", value: "\(totalFiles)")
                    }
                }
            }

            Spacer()

            Button {
                isLoading = true
                sessions = []
                Task {
                    sessions = AISessionLogParser.parseAll()
                    isLoading = false
                }
            } label: {
                Label("Reload", systemImage: "arrow.clockwise")
            }
            .disabled(isLoading)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var toolbar: some View {
        HStack(spacing: 12) {
            Picker("Project", selection: $projectFilter) {
                ForEach(projectNames, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .frame(width: 240)

            TextField("Search commands, files, models...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 300)

            Spacer()

            Text("\(filteredSessions.count) session(s)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Session List

    @ViewBuilder
    private var sessionList: some View {
        if filteredSessions.isEmpty && !isLoading {
            Text("No sessions match the current filter.")
                .foregroundStyle(.secondary)
                .padding(.vertical, 20)
        } else {
            LazyVStack(spacing: 8) {
                ForEach(filteredSessions) { session in
                    SessionCard(session: session)
                }
            }
        }
    }

    // MARK: - Helpers

    private func abbreviatedProject(_ path: String) -> String {
        let components = path.split(separator: "/")
        if components.count >= 2 {
            return String(components.suffix(2).joined(separator: "/"))
        }
        return path
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

// MARK: - Stat Pill

private struct StatPill: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Text(value)
                .fontWeight(.semibold)
            Text(label)
                .foregroundStyle(.secondary)
        }
        .font(.callout)
    }
}

// MARK: - Session Card

private struct SessionCard: View {
    let session: AISessionLog
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row — always visible
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(abbreviatedProject(session.projectPath))
                            .fontWeight(.medium)
                        HStack(spacing: 12) {
                            if let start = session.startedAt {
                                Text(start, format: .dateTime.month(.abbreviated).day().hour().minute())
                            }
                            if let branch = session.gitBranch {
                                Label(branch, systemImage: "arrow.triangle.branch")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 16) {
                        miniStat(icon: "clock", value: durationText)
                        miniStat(icon: "bubble.left.and.bubble.right", value: "\(session.totalTurns)")
                        miniStat(icon: "number", value: formatTokens(session.tokens.output))
                        if !session.bashCommands.isEmpty {
                            miniStat(icon: "terminal", value: "\(session.bashCommands.count)")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(12)

            // Detail — shown when expanded
            if expanded {
                Divider()
                VStack(alignment: .leading, spacing: 16) {
                    overviewSection
                    if !session.bashCommands.isEmpty {
                        bashSection
                    }
                    if !session.filesTouched.isEmpty {
                        filesSection
                    }
                    if !session.toolsUsed.isEmpty {
                        toolsSection
                    }
                }
                .padding(12)
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Overview

    @ViewBuilder
    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Overview")

            let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                DetailCell(label: "Duration", value: durationText)
                DetailCell(label: "Human Turns", value: "\(session.humanTurns)")
                DetailCell(label: "Assistant Turns", value: "\(session.assistantTurns)")
                DetailCell(label: "Input Tokens", value: formatTokens(session.tokens.input))
                DetailCell(label: "Output Tokens", value: formatTokens(session.tokens.output))
                DetailCell(label: "Cache Read", value: formatTokens(session.tokens.cacheRead))
                DetailCell(label: "Cache Write", value: formatTokens(session.tokens.cacheCreation))
                DetailCell(label: "Models", value: session.modelsUsed.joined(separator: ", "))
                DetailCell(label: "Session ID", value: String(session.id.prefix(8)) + "...")
            }
        }
    }

    // MARK: - Bash Commands

    @ViewBuilder
    private var bashSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Bash Commands (\(session.bashCommands.count))")

            ForEach(Array(session.bashCommands.prefix(30).enumerated()), id: \.offset) { _, command in
                Text(command)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            }

            if session.bashCommands.count > 30 {
                Text("... and \(session.bashCommands.count - 30) more commands")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Files Touched

    @ViewBuilder
    private var filesSection: some View {
        let grouped = Dictionary(grouping: session.filesTouched, by: \.action)

        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Files Touched (\(session.filesTouched.count))")

            ForEach(AIFileAction.allCases, id: \.self) { action in
                if let files = grouped[action], !files.isEmpty {
                    fileActionGroup(action: action, files: files)
                }
            }
        }
    }

    @ViewBuilder
    private func fileActionGroup(action: AIFileAction, files: [AIFileTouched]) -> some View {
        let uniquePaths = Array(Set(files.map(\.path)).sorted())

        DisclosureGroup {
            ForEach(uniquePaths.prefix(20), id: \.self) { path in
                Text(path)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if uniquePaths.count > 20 {
                Text("... and \(uniquePaths.count - 20) more")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: actionIcon(action))
                    .foregroundStyle(actionColor(action))
                Text("\(actionLabel(action)) (\(uniquePaths.count))")
                    .font(.callout)
            }
        }
    }

    // MARK: - Tools Used

    @ViewBuilder
    private var toolsSection: some View {
        let sorted = session.toolsUsed.sorted { $0.value > $1.value }

        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Tools Used")

            HStack(spacing: 8) {
                ForEach(sorted, id: \.key) { tool, count in
                    HStack(spacing: 4) {
                        Text(tool)
                            .fontWeight(.medium)
                        Text("\(count)")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
                }
            }
        }
    }

    // MARK: - Helpers

    private var durationText: String {
        guard let hours = session.durationHours else { return "—" }
        if hours < 1 {
            return String(format: "%.0fm", hours * 60)
        }
        return String(format: "%.1fh", hours)
    }

    private func abbreviatedProject(_ path: String) -> String {
        let components = path.split(separator: "/")
        if components.count >= 2 {
            return String(components.suffix(2).joined(separator: "/"))
        }
        return path
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    @ViewBuilder
    private func miniStat(icon: String, value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
            Text(value)
        }
    }

    private func actionIcon(_ action: AIFileAction) -> String {
        switch action {
        case .read: "eye"
        case .write: "square.and.pencil"
        case .edit: "pencil.line"
        case .multiEdit: "pencil.and.list.clipboard"
        case .search: "magnifyingglass"
        }
    }

    private func actionColor(_ action: AIFileAction) -> Color {
        switch action {
        case .read: .blue
        case .write: .orange
        case .edit: .green
        case .multiEdit: .green
        case .search: .purple
        }
    }

    private func actionLabel(_ action: AIFileAction) -> String {
        switch action {
        case .read: "Read"
        case .write: "Written"
        case .edit: "Edited"
        case .multiEdit: "Multi-Edited"
        case .search: "Searched"
        }
    }
}

// MARK: - Reusable Components

private struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
    }
}

private struct DetailCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}
