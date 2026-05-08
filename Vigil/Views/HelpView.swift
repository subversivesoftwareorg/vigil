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

                // Tabs
                VStack(alignment: .leading, spacing: 20) {
                    Text("The Four Modes")
                        .font(.title2)
                        .fontWeight(.bold)

                    HelpSection(
                        icon: "gauge.with.dots.needle.bottom.50percent",
                        color: .blue,
                        title: "Simple",
                        description: "A clean overview showing how many processes are running and how much file activity is happening. Start here if you just want to know everything's normal."
                    )

                    HelpSection(
                        icon: "terminal",
                        color: .green,
                        title: "Expert",
                        description: "The full picture. See every running process with its memory usage, disk I/O rates, and category. Click a process to open the inspector panel with detailed information — what it does, how much it's reading and writing, and whether its behavior is normal. The right pane shows real-time file system events."
                    )

                    HelpSection(
                        icon: "brain",
                        color: .purple,
                        title: "Heuristics",
                        description: "Automated analysis in plain English. Vigil runs six checks against your system and tells you what it found — like an unrecognized process doing heavy disk work, or a critical system process that's missing. Each finding includes an explanation and a recommendation. The health score gives you a quick gut-feel number."
                    )

                    HelpSection(
                        icon: "chart.bar",
                        color: .orange,
                        title: "Reporting",
                        description: "Long-term behavioral trends. Vigil saves daily I/O statistics for every process and compares them across time windows — 7 days vs 30 days, 30 vs 90, 90 vs 365. This surfaces processes that have changed behavior over time, which can reveal software updates, new background activity, or gradual resource creep."
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
                        ScoreRow(range: "90–100", label: "Good", color: .green,
                                 description: "Everything looks normal")
                        ScoreRow(range: "70–89", label: "Fair", color: .yellow,
                                 description: "A few informational findings")
                        ScoreRow(range: "50–69", label: "Concerning", color: .orange,
                                 description: "Multiple warnings worth reviewing")
                        ScoreRow(range: "0–49", label: "Poor", color: .red,
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
