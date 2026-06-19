import SwiftUI
import Sparkle

@main
struct VigilApp: App {
    @State private var monitoringStore = MonitoringStore()
    @Environment(\.openWindow) private var openWindow
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
    )

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environment(monitoringStore)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Vigil") {
                    openWindow(id: "about")
                }
            }
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
            CommandGroup(replacing: .help) {
                Button("Vigil Help") {
                    openWindow(id: "help")
                }
                .keyboardShortcut("?", modifiers: .command)

                Divider()

                Button("Welcome Walkthrough") {
                    NotificationCenter.default.post(name: .showWalkthrough, object: nil)
                }
            }
        }

        MenuBarExtra("Vigil", systemImage: "eye.circle") {
            MenuBarView()
                .environment(monitoringStore)
        }
        .menuBarExtraStyle(.window)

        Window("About Vigil", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)

        Window("Vigil Help", id: "help") {
            HelpView()
        }
        .defaultSize(width: 520, height: 600)
    }
}
