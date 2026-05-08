import Testing
@testable import Vigil

@Suite("ProcessDatabase")
struct ProcessDatabaseTests {

    @Test("exact match returns known process")
    func exactMatch() {
        let result = ProcessDatabase.lookup("kernel_task")
        #expect(result != nil)
        #expect(result?.category == .kernel)
        #expect(result?.expectation == .alwaysRunning)
    }

    @Test("prefix match works for bundle-ID-style names")
    func prefixMatch() {
        let result = ProcessDatabase.lookup("com.apple.WebKit.Networking.xpc")
        #expect(result != nil)
        #expect(result?.category == .appleApp)
    }

    @Test("unknown process returns nil")
    func unknownProcess() {
        let result = ProcessDatabase.lookup("totally_fake_process_xyz")
        #expect(result == nil)
    }

    @Test("case-sensitive exact match", arguments: ["launchd", "WindowServer", "Finder", "mDNSResponder"])
    func knownSystemProcesses(name: String) {
        #expect(ProcessDatabase.lookup(name) != nil, "\(name) should be in the database")
    }

    @Test("all categories have system images")
    func categoriesHaveImages() {
        for category in ProcessKnowledge.Category.allCases {
            #expect(!category.systemImage.isEmpty, "\(category.rawValue) should have a systemImage")
        }
    }

    @Test("always-running processes include the essentials",
          arguments: ["kernel_task", "launchd", "WindowServer", "securityd"])
    func alwaysRunningEssentials(name: String) {
        let result = ProcessDatabase.lookup(name)
        #expect(result?.expectation == .alwaysRunning, "\(name) should be alwaysRunning")
    }

    @Test("user-launched apps are marked correctly",
          arguments: ["Safari", "Xcode", "Slack", "Spotify"])
    func userLaunchedApps(name: String) {
        let result = ProcessDatabase.lookup(name)
        #expect(result?.expectation == .userLaunched, "\(name) should be userLaunched")
    }
}
