import Foundation
import Testing
@testable import Vigil

@Suite("HeuristicsEngine")
struct HeuristicsEngineTests {

    @Test("healthy system produces high score and no critical findings")
    @MainActor func healthySystem() {
        // Simulate a set of known system processes
        let processes = [
            makeSnapshot(pid: 1, name: "launchd", path: "/sbin/launchd"),
            makeSnapshot(pid: 2, name: "WindowServer", path: "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/Resources/WindowServer"),
            makeSnapshot(pid: 3, name: "Dock", path: "/System/Library/CoreServices/Dock.app/Contents/MacOS/Dock"),
            makeSnapshot(pid: 4, name: "Finder", path: "/System/Library/CoreServices/Finder.app/Contents/MacOS/Finder"),
            makeSnapshot(pid: 5, name: "securityd", path: "/usr/sbin/securityd"),
            makeSnapshot(pid: 6, name: "trustd", path: "/usr/libexec/trustd"),
            makeSnapshot(pid: 7, name: "mDNSResponder", path: "/usr/sbin/mDNSResponder"),
            makeSnapshot(pid: 8, name: "configd", path: "/usr/libexec/configd"),
            makeSnapshot(pid: 9, name: "logd", path: "/usr/libexec/logd"),
            makeSnapshot(pid: 10, name: "kernel_task"),
        ]

        let engine = HeuristicsEngine(processes: processes, ioRates: [:], baseline: IOBaseline())
        let result = engine.analyze()

        #expect(result.healthScore >= 80)
        #expect(result.findings.filter { $0.severity == .critical }.isEmpty)
        #expect(result.knownProcesses == 10)
    }

    @Test("detects unknown process with high I/O")
    @MainActor func unknownHighIO() {
        let processes = [
            makeSnapshot(pid: 99, name: "suspicious_thing", path: "/tmp/suspicious_thing",
                         diskBytesRead: 50_000_000),
        ]

        let rate = ProcessIORate(pid: 99, processName: "suspicious_thing",
                                  readBytesPerSec: 5_000_000, writeBytesPerSec: 0,
                                  logicalWritesPerSec: 0, interval: 2)

        let engine = HeuristicsEngine(
            processes: processes,
            ioRates: [99: rate],
            baseline: IOBaseline()
        )
        let result = engine.analyze()

        let finding = result.findings.first { $0.check == .unknownHighIO }
        #expect(finding != nil)
        #expect(finding!.severity == .warning || finding!.severity == .critical)
        #expect(finding!.affectedProcess == "suspicious_thing")
    }

    @Test("detects missing essential process")
    @MainActor func missingEssential() {
        // No WindowServer in the list
        let processes = [
            makeSnapshot(pid: 1, name: "launchd"),
            makeSnapshot(pid: 2, name: "Dock"),
            makeSnapshot(pid: 3, name: "Finder"),
            makeSnapshot(pid: 5, name: "securityd"),
            makeSnapshot(pid: 6, name: "trustd"),
            makeSnapshot(pid: 7, name: "mDNSResponder"),
            makeSnapshot(pid: 8, name: "configd"),
            makeSnapshot(pid: 9, name: "logd"),
            makeSnapshot(pid: 10, name: "kernel_task"),
        ]

        let engine = HeuristicsEngine(processes: processes, ioRates: [:], baseline: IOBaseline())
        let result = engine.analyze()

        let finding = result.findings.first { $0.check == .missingEssential }
        #expect(finding != nil)
        #expect(finding!.affectedProcess == "WindowServer")
    }

    @Test("phantom process is flagged when no path and no knowledge")
    @MainActor func phantomProcess() {
        let processes = [
            makeSnapshot(pid: 999, name: "mystery", path: nil, memoryBytes: 50_000_000),
        ]

        let engine = HeuristicsEngine(processes: processes, ioRates: [:], baseline: IOBaseline())
        let result = engine.analyze()

        let finding = result.findings.first { $0.check == .phantomProcess }
        #expect(finding != nil)
        #expect(finding!.affectedProcess == "mystery")
    }

    @Test("passed checks are generated for non-triggered checks")
    @MainActor func passedChecks() {
        let processes = [
            makeSnapshot(pid: 1, name: "launchd", path: "/sbin/launchd"),
            makeSnapshot(pid: 2, name: "WindowServer", path: "/System/Library/WindowServer"),
            makeSnapshot(pid: 3, name: "Dock", path: "/System/Library/Dock"),
            makeSnapshot(pid: 4, name: "Finder", path: "/System/Library/Finder"),
            makeSnapshot(pid: 5, name: "securityd", path: "/usr/sbin/securityd"),
            makeSnapshot(pid: 6, name: "trustd", path: "/usr/libexec/trustd"),
            makeSnapshot(pid: 7, name: "mDNSResponder", path: "/usr/sbin/mDNSResponder"),
            makeSnapshot(pid: 8, name: "configd", path: "/usr/libexec/configd"),
            makeSnapshot(pid: 9, name: "logd", path: "/usr/libexec/logd"),
            makeSnapshot(pid: 10, name: "kernel_task"),
        ]

        let engine = HeuristicsEngine(processes: processes, ioRates: [:], baseline: IOBaseline())
        let result = engine.analyze()

        // Most checks should pass for a healthy system
        #expect(result.passedChecks.count >= 4)
    }

    @Test("health score decreases with findings")
    @MainActor func scoreDecreasesWithFindings() {
        // System missing essential processes → lower score
        let engine = HeuristicsEngine(processes: [], ioRates: [:], baseline: IOBaseline())
        let result = engine.analyze()

        // Missing all visible essentials = warning findings that lower the score
        #expect(result.healthScore < 60)
        #expect(result.healthLevel == .concerning || result.healthLevel == .poor)
    }
}
