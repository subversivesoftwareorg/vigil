import SwiftUI

/// The root view for the Vigil window.
/// Provides mode switching between the four visualization modes.
struct MainWindowView: View {
    @Environment(MonitoringStore.self) private var store
    @State private var selectedMode: ViewMode = .simple

    var body: some View {
        NavigationSplitView {
            List(ViewMode.allCases, selection: $selectedMode) { mode in
                Label(mode.displayName, systemImage: mode.systemImage)
                    .tag(mode)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            switch selectedMode {
            case .simple:
                SimpleModeView()
            case .expert:
                ExpertModeView()
            case .heuristics:
                HeuristicsModeView()
            case .reporting:
                ReportingModeView()
            }
        }
        .navigationTitle("Vigil")
        .task {
            let processMonitor = ProcessMonitor()
            let fileMonitor = FileMonitor()
            let database = try? Database()
            store.configure(processSource: processMonitor, fileSource: fileMonitor,
                            database: database)
            await store.startMonitoring()
        }
    }
}

// MARK: - View Mode

enum ViewMode: String, CaseIterable, Identifiable {
    case simple
    case expert
    case heuristics
    case reporting

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .simple: "Simple"
        case .expert: "Expert"
        case .heuristics: "Heuristics"
        case .reporting: "Reporting"
        }
    }

    var systemImage: String {
        switch self {
        case .simple: "gauge.with.dots.needle.bottom.50percent"
        case .expert: "terminal"
        case .heuristics: "brain"
        case .reporting: "chart.bar"
        }
    }
}
