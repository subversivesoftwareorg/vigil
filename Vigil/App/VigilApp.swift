import SwiftUI

@main
struct VigilApp: App {
    @State private var monitoringStore = MonitoringStore()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environment(monitoringStore)
        }
        .commands {
            CommandGroup(replacing: .help) {
                Button("Vigil Help") {
                    openWindow(id: "help")
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }

        MenuBarExtra("Vigil", systemImage: "eye.circle") {
            MenuBarView()
                .environment(monitoringStore)
        }
        .menuBarExtraStyle(.window)

        Window("Vigil Help", id: "help") {
            HelpView()
        }
        .defaultSize(width: 520, height: 600)
    }
}
