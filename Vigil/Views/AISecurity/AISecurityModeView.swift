import SwiftUI

struct AISecurityModeView: View {
    @Environment(MonitoringStore.self) private var store
    @State private var selectedCategory: SignalCategory?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                summaryHeader
                if let result = store.securityScanResult {
                    severityOverview(result)
                    signalsList(result)
                    sessionSummary(result)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            if store.securityScanResult == nil {
                store.runSecurityScan()
            }
        }
    }

    // MARK: - Summary Header

    @ViewBuilder
    private var summaryHeader: some View {
        HStack(spacing: 24) {
            Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                .font(.system(size: 36))
                .foregroundStyle(headerColor)

            VStack(alignment: .leading, spacing: 4) {
                if store.isScanningSecurity {
                    Text("Scanning AI Session Logs...")
                        .font(.title2)
                        .fontWeight(.bold)
                    ProgressView()
                        .controlSize(.small)
                } else if let result = store.securityScanResult {
                    Text(headerTitle(result))
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(headerSubtitle(result))
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    Text("AI Security Analysis")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Analyzes Claude Code session logs for sensitive file access, suspicious commands, excessive token usage, and agent autonomy patterns.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                store.runSecurityScan()
            } label: {
                Label("Rescan", systemImage: "arrow.clockwise")
            }
            .disabled(store.isScanningSecurity)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var headerColor: Color {
        guard let result = store.securityScanResult else { return .secondary }
        if result.warningCount > 0 { return .red }
        if result.concernCount > 0 { return .orange }
        if result.infoCount > 0 { return .blue }
        return .green
    }

    private func headerTitle(_ result: AISecurityScanResult) -> String {
        if result.signals.isEmpty {
            return "No Security Signals"
        }
        let total = result.signals.count
        let label = total == 1 ? "Signal" : "Signals"
        return "\(total) \(label) Detected"
    }

    private func headerSubtitle(_ result: AISecurityScanResult) -> String {
        var parts: [String] = []
        parts.append("\(result.sessions.count) session(s) across \(result.projectCount) project(s)")
        if result.warningCount > 0 { parts.append("\(result.warningCount) warning(s)") }
        if result.concernCount > 0 { parts.append("\(result.concernCount) concern(s)") }
        if result.infoCount > 0 { parts.append("\(result.infoCount) info") }
        return parts.joined(separator: " \u{2022} ")
    }

    // MARK: - Severity Overview

    @ViewBuilder
    private func severityOverview(_ result: AISecurityScanResult) -> some View {
        HStack(spacing: 16) {
            SeverityBadge(severity: .warning, count: result.warningCount)
            SeverityBadge(severity: .concern, count: result.concernCount)
            SeverityBadge(severity: .info, count: result.infoCount)
            SeverityBadge(severity: .healthy, count: result.healthyCount)
        }
    }

    // MARK: - Signals List

    @ViewBuilder
    private func signalsList(_ result: AISecurityScanResult) -> some View {
        let filtered = filteredSignals(result)

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Findings")
                    .font(.headline)
                Spacer()
                categoryFilter
            }

            if filtered.isEmpty {
                Text("No signals match the current filter.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(filtered) { signal in
                    SignalCard(signal: signal)
                }
            }
        }
    }

    private func filteredSignals(_ result: AISecurityScanResult) -> [AISecuritySignal] {
        guard let cat = selectedCategory else { return result.signals }
        return result.signals.filter { $0.category == cat }
    }

    @ViewBuilder
    private var categoryFilter: some View {
        Picker("Category", selection: $selectedCategory) {
            Text("All").tag(nil as SignalCategory?)
            ForEach(SignalCategory.allCases, id: \.self) { cat in
                Label(cat.displayName, systemImage: cat.systemImage)
                    .tag(cat as SignalCategory?)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 200)
    }

    // MARK: - Session Summary

    @ViewBuilder
    private func sessionSummary(_ result: AISecurityScanResult) -> some View {
        if !result.sessions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Scanned Sessions")
                    .font(.headline)

                let sorted = result.sessions.sorted {
                    ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast)
                }

                ForEach(sorted.prefix(20)) { session in
                    SessionRow(session: session, signalCount: signalCount(for: session, in: result))
                }

                if result.sessions.count > 20 {
                    Text("... and \(result.sessions.count - 20) more sessions")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
        }
    }

    private func signalCount(for session: AISessionLog, in result: AISecurityScanResult) -> Int {
        result.signals.filter { $0.sessionID == session.id }.count
    }
}

// MARK: - Severity Badge

private struct SeverityBadge: View {
    let severity: SignalSeverity
    let count: Int

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(severity.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private var color: Color {
        switch severity {
        case .warning: .red
        case .concern: .orange
        case .info: .blue
        case .healthy: .green
        }
    }
}

// MARK: - Signal Card

private struct SignalCard: View {
    let signal: AISecuritySignal
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    severityDot
                    Image(systemName: signal.category.systemImage)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(signal.title)
                            .fontWeight(.medium)
                        Text(signal.category.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let project = signal.projectPath {
                        Text(abbreviatedProject(project))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 6) {
                    Text(signal.detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    if !signal.evidence.isEmpty {
                        Text(signal.evidence)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                    }

                    if let sessionID = signal.sessionID {
                        Text("Session: \(sessionID)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.leading, 28)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var severityDot: some View {
        Circle()
            .fill(severityColor)
            .frame(width: 8, height: 8)
    }

    private var severityColor: Color {
        switch signal.severity {
        case .warning: .red
        case .concern: .orange
        case .info: .blue
        case .healthy: .green
        }
    }

    private func abbreviatedProject(_ path: String) -> String {
        let components = path.split(separator: "/")
        if components.count >= 2 {
            return String(components.suffix(2).joined(separator: "/"))
        }
        return path
    }
}

// MARK: - Session Row

private struct SessionRow: View {
    let session: AISessionLog
    let signalCount: Int

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(abbreviatedProject(session.projectPath))
                    .fontWeight(.medium)
                    .font(.callout)
                HStack(spacing: 8) {
                    if let start = session.startedAt {
                        Text(start, style: .date)
                    }
                    if let hours = session.durationHours {
                        Text(String(format: "%.1fh", hours))
                    }
                    Text("\(session.totalTurns) turns")
                    if session.tokens.output > 0 {
                        Text(formatTokens(session.tokens.output) + " out")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if signalCount > 0 {
                Text("\(signalCount)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.orange, in: Capsule())
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
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
}
