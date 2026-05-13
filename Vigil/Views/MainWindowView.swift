import SwiftUI

/// The root view for the Vigil window.
/// Provides mode switching between the four visualization modes.
struct MainWindowView: View {
    @Environment(MonitoringStore.self) private var store
    @State private var selectedMode: ViewMode = .overview

    var body: some View {
        NavigationSplitView {
            List(ViewMode.allCases, selection: $selectedMode) { mode in
                Label(mode.displayName, systemImage: mode.systemImage)
                    .tag(mode)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            switch selectedMode {
            case .overview:
                OverviewModeView()
            case .processes:
                ProcessesModeView()
            case .fileActivity:
                FileActivityModeView()
            case .history:
                HistoryModeView()
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
    case overview
    case processes
    case fileActivity
    case history

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .overview: "Overview"
        case .processes: "Processes"
        case .fileActivity: "File Activity"
        case .history: "History"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .processes: "cpu"
        case .fileActivity: "doc.text.magnifyingglass"
        case .history: "clock.arrow.circlepath"
        }
    }
}
