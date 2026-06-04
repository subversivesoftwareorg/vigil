import SwiftUI

/// First-launch walkthrough that introduces Vigil's main capabilities.
struct WalkthroughView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0

    private let pages: [WalkthroughPage] = [
        WalkthroughPage(
            icon: "eye.circle.fill",
            iconColor: .blue,
            title: "Welcome to Vigil",
            subtitle: "See what your Mac is doing",
            bullets: [
                Bullet(icon: "cpu", text: "Monitors every running process in real time"),
                Bullet(icon: "doc.text.magnifyingglass", text: "Watches file activity across your system"),
                Bullet(icon: "brain", text: "Tracks AI tools and their impact on your Mac"),
                Bullet(icon: "lock.shield", text: "Runs entirely on your Mac — no data sent anywhere"),
            ]
        ),
        WalkthroughPage(
            icon: "desktopcomputer",
            iconColor: .green,
            title: "System Monitoring",
            subtitle: "Understand what's running and why",
            bullets: [
                Bullet(icon: "square.grid.2x2", text: "Overview — your dashboard with health score and findings"),
                Bullet(icon: "cpu", text: "Processes — everything running, sorted and categorized"),
                Bullet(icon: "doc.text.magnifyingglass", text: "File Activity — real-time file changes attributed to apps"),
                Bullet(icon: "icloud.and.arrow.up.and.arrow.down", text: "File Sharing — cloud sync and backup activity"),
            ]
        ),
        WalkthroughPage(
            icon: "brain.filled.head.profile",
            iconColor: .cyan,
            title: "AI Visibility",
            subtitle: "See the footprint of AI on your Mac",
            bullets: [
                Bullet(icon: "brain", text: "AI Activity — which AI tools are running and what they're doing"),
                Bullet(icon: "list.bullet.clipboard", text: "AI Inventory — catalog of AI tools and models on your system"),
                Bullet(icon: "shield.lefthalf.filled.badge.checkmark", text: "AI Security — security posture of your AI stack"),
                Bullet(icon: "note.text", text: "AI Logs — detailed log of AI-related events"),
            ]
        ),
        WalkthroughPage(
            icon: "checkmark.circle.fill",
            iconColor: .green,
            title: "You're All Set",
            subtitle: "Vigil is now monitoring your Mac",
            bullets: [
                Bullet(icon: "square.grid.2x2", text: "Start with Overview to see your system health at a glance"),
                Bullet(icon: "chart.line.uptrend.xyaxis", text: "Vigil learns what's normal and flags what isn't"),
                Bullet(icon: "questionmark.circle", text: "Reopen this guide anytime from Help → Welcome Walkthrough"),
            ]
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    pageView(page)
                        .tag(index)
                }
            }
            .tabViewStyle(.automatic)

            // Navigation
            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation { currentPage -= 1 }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }

                Spacer()

                if currentPage < pages.count - 1 {
                    Button("Next") {
                        withAnimation { currentPage += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .frame(width: 520, height: 440)
    }

    private func pageView(_ page: WalkthroughPage) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: 48))
                .foregroundStyle(page.iconColor)

            VStack(spacing: 6) {
                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)
                Text(page.subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(page.bullets) { bullet in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: bullet.icon)
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text(bullet.text)
                            .font(.body)
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Data

private struct WalkthroughPage {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let bullets: [Bullet]
}

private struct Bullet: Identifiable {
    let icon: String
    let text: String
    var id: String { text }
}
