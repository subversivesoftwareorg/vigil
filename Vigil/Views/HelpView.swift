import SwiftUI

/// Help window explaining what Vigil does and how to use it.
struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // App header
                HStack(spacing: 16) {
                    Image(systemName: "eye.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading) {
                        Text("Vigil")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("See what your Mac is doing")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Vigil monitors processes and file activity on your Mac, helping you understand what's running, how it's behaving, and whether anything looks unusual. It's like a behavioral antivirus — it watches and reports, but never blocks.")
                    .font(.body)

                Divider()

                // Modes
                VStack(alignment: .leading, spacing: 20) {
                    Text("The Four Modes")
                        .font(.title2)
                        .fontWeight(.bold)

                    HelpSection(
                        icon: "square.grid.2x2",
                        color: .blue,
                        title: "Overview",
                        description: "Your dashboard. Shows system health at a glance — a health score, any concerns Vigil has found, a breakdown of what's running (system services, Apple apps, third-party apps, unrecognized), and a summary of recent file activity. Start here."
                    )

                    HelpSection(
                        icon: "cpu",
                        color: .green,
                        title: "Processes",
                        description: "Everything running on your Mac. Each process shows what it is, what category it belongs to, and how it's behaving. Click any process to open the inspector with full details — memory, disk I/O, energy usage, and whether its behavior is normal. Sort by name, memory, I/O, or category."
                    )

                    HelpSection(
                        icon: "doc.text.magnifyingglass",
                        color: .purple,
                        title: "File Activity",
                        description: "What's happening on your disk. See files being created, modified, and deleted in real time. Group by directory to find hot spots, or switch to timeline view. Vigil attributes file changes to known apps where possible — so you can see that Chrome is writing to its cache, or Xcode is producing build output."
                    )

                    HelpSection(
                        icon: "clock.arrow.circlepath",
                        color: .orange,
                        title: "History",
                        description: "The full analysis. Shows current anomalies (unrecognized processes with high I/O, missing system processes, behavioral outliers) alongside long-term trends. Vigil compares each process's recent activity against its historical baseline and tells you in plain language what's changed — like \"Writing 5x more than its 30-day average.\""
                    )
                }

                Divider()

                // How it works
                VStack(alignment: .leading, spacing: 16) {
                    Text("How It Works")
                        .font(.title2)
                        .fontWeight(.bold)

                    InfoRow(
                        icon: "cpu",
                        text: "**Process monitoring** — Vigil polls the system every 2 seconds using macOS system APIs to capture what's running, how much memory and CPU each process uses, and how much data it reads and writes."
                    )

                    InfoRow(
                        icon: "doc.text.magnifyingglass",
                        text: "**File monitoring** — Uses Apple's FSEvents framework (the same system Spotlight uses) to watch for file changes across your home directory."
                    )

                    InfoRow(
                        icon: "chart.line.uptrend.xyaxis",
                        text: "**Baseline learning** — Vigil builds a statistical profile of each process's normal I/O behavior over time using Welford's algorithm. This lets it detect when something deviates from its usual pattern."
                    )

                    InfoRow(
                        icon: "externaldrive",
                        text: "**Data storage** — Daily statistics are saved to a local SQLite database in ~/Library/Application Support/Vigil/. No data is sent anywhere."
                    )

                    InfoRow(
                        icon: "lock.shield",
                        text: "**Privacy** — Vigil runs entirely in user space with no special permissions. It can see the same processes you'd see in Activity Monitor. All data stays on your Mac."
                    )
                }

                Divider()

                // Health score
                VStack(alignment: .leading, spacing: 12) {
                    Text("Health Score")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("The health score starts at 100 and decreases based on findings:")

                    VStack(alignment: .leading, spacing: 8) {
                        ScoreRow(range: "90-100", label: "Good", color: .green,
                                 description: "Everything looks normal")
                        ScoreRow(range: "70-89", label: "Fair", color: .yellow,
                                 description: "A few informational findings")
                        ScoreRow(range: "50-69", label: "Concerning", color: .orange,
                                 description: "Multiple warnings worth reviewing")
                        ScoreRow(range: "0-49", label: "Poor", color: .red,
                                 description: "Critical findings need attention")
                    }
                }

                // Footer
                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                    Text("Vigil is part of the Subversive Software family.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(32)
        }
        .frame(minWidth: 480, minHeight: 500)
    }
}

// MARK: - Supporting Views

private struct HelpSection: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct InfoRow: View {
    let icon: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(text)
                .font(.body)
        }
    }
}

private struct ScoreRow: View {
    let range: String
    let label: String
    let color: Color
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Text(range)
                .font(.caption)
                .monospacedDigit()
                .frame(width: 50, alignment: .trailing)
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .fontWeight(.medium)
                .frame(width: 90, alignment: .leading)
            Text(description)
                .foregroundStyle(.secondary)
        }
        .font(.body)
    }
}
