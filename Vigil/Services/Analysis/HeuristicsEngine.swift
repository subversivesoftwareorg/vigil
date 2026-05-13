import Foundation

/// Runs automated checks against live process data and baselines to surface
/// plain-English findings for regular users.
struct HeuristicsEngine {

    let processes: [ProcessSnapshot]
    let ioRates: [Int32: ProcessIORate]
    let baseline: IOBaseline

    /// Run all checks and return a complete analysis.
    @MainActor
    func analyze() -> HeuristicsResult {
        let findings = runAllChecks()
        let knownCount = processes.filter { ProcessDatabase.lookup($0.displayName) != nil }.count
        let unknownCount = processes.count - knownCount
        let score = computeHealthScore(findings: findings)

        return HeuristicsResult(
            healthScore: score,
            totalProcesses: processes.count,
            knownProcesses: knownCount,
            unknownProcesses: unknownCount,
            findings: findings.sorted { $0.severity > $1.severity },
            passedChecks: generatePassedChecks(findings: findings)
        )
    }

    // MARK: - All Checks

    @MainActor
    private func runAllChecks() -> [Finding] {
        var findings: [Finding] = []
        findings.append(contentsOf: checkUnknownHighIO())
        findings.append(contentsOf: checkMissingEssentials())
        findings.append(contentsOf: checkExpectationViolations())
        findings.append(contentsOf: checkIOAnomalies())
        findings.append(contentsOf: checkHighEnergy())
        findings.append(contentsOf: checkPhantomProcesses())
        return findings
    }

    // MARK: - Check: Unknown Processes with High I/O

    private func checkUnknownHighIO() -> [Finding] {
        processes.compactMap { process -> Finding? in
            guard ProcessDatabase.lookup(process.displayName) == nil,
                  let rate = ioRates[process.pid] else { return nil }

            let totalIO = rate.readBytesPerSec + rate.writeBytesPerSec
            guard totalIO > 1_000_000 else { return nil } // >1 MB/s

            let ioDesc = ByteCountFormatter.string(fromByteCount: Int64(totalIO), countStyle: .memory)

            return Finding(
                id: "unknown-high-io-\(process.pid)",
                severity: totalIO > 10_000_000 ? .critical : .warning,
                check: .unknownHighIO,
                title: "Unrecognized process with high disk activity",
                description: "\"\(process.displayName)\" (PID \(process.pid)) is transferring \(ioDesc)/s and is not in Vigil's process database. This could be a legitimate app Vigil doesn't know about yet, or it could be worth investigating.",
                recommendation: "Check what this process is by looking at its path: \(process.path ?? "unknown"). If you recognize it, it's fine — Vigil's database doesn't cover every app.",
                affectedProcess: process.displayName,
                affectedPid: process.pid
            )
        }
    }

    // MARK: - Check: Missing Essential Processes

    private func checkMissingEssentials() -> [Finding] {
        // Only check for processes that are reliably visible from user space.
        // kernel_task (PID 0) is not enumerable via proc_listallpids, and some
        // privileged daemons (securityd, trustd, logd) may fail both proc_pidinfo
        // and proc_name, making them invisible to user-space monitoring.
        // We check process names AND raw names since displayName uses the path's
        // last component when available.
        let essentials = [
            "launchd", "WindowServer", "Dock", "Finder",
            "mDNSResponder", "configd"
        ]

        let runningNames = Set(processes.map(\.displayName))
        let runningRawNames = Set(processes.map(\.name))
        let allNames = runningNames.union(runningRawNames)

        return essentials.compactMap { name -> Finding? in
            guard !allNames.contains(name) else { return nil }

            return Finding(
                id: "missing-essential-\(name)",
                severity: .warning,
                check: .missingEssential,
                title: "\(name) is not running",
                description: "\(name) is a core system process that is expected to always be running and is normally visible to Vigil. Its absence could indicate a system issue.",
                recommendation: "This is unusual. If your Mac is behaving normally otherwise, it may be a temporary state. If you're experiencing issues, consider restarting your Mac.",
                affectedProcess: name,
                affectedPid: nil
            )
        }
    }

    // MARK: - Check: Expectation Violations

    private func checkExpectationViolations() -> [Finding] {
        // Find "transient" processes that have been running with significant CPU time
        // (a proxy for running a long time — we don't have process start time without
        // more API work, but high CPU time on a transient process is the signal)
        processes.compactMap { process -> Finding? in
            guard let knowledge = ProcessDatabase.lookup(process.displayName),
                  knowledge.expectation == .transient,
                  process.cpuUsage > 300 // >5 minutes of CPU time
            else { return nil }

            let cpuMinutes = Int(process.cpuUsage / 60)

            return Finding(
                id: "long-transient-\(process.pid)",
                severity: .info,
                check: .expectationViolation,
                title: "\(process.displayName) has been running longer than expected",
                description: "This process is normally short-lived but has accumulated \(cpuMinutes) minutes of CPU time. For \(knowledge.category.rawValue) processes like this, that's unusual.",
                recommendation: "This might just be a large job in progress (like a Spotlight re-index or a long build). If it persists, it could be stuck.",
                affectedProcess: process.displayName,
                affectedPid: process.pid
            )
        }
    }

    // MARK: - Check: I/O Anomalies (Known Processes)

    @MainActor
    private func checkIOAnomalies() -> [Finding] {
        processes.compactMap { process -> Finding? in
            guard let knowledge = ProcessDatabase.lookup(process.displayName),
                  let rate = ioRates[process.pid],
                  let score = baseline.anomalyScore(for: rate),
                  score.severity >= .anomalous
            else { return nil }

            let metric = abs(score.readZScore) > abs(score.writeZScore) ? "reading" : "writing"
            let sigma = String(format: "%.1f", score.maxZScore)

            // Provide context-aware explanation based on what the process does
            let context = contextForAnomaly(knowledge: knowledge, metric: metric)

            return Finding(
                id: "io-anomaly-\(process.pid)",
                severity: score.severity == .extreme ? .warning : .info,
                check: .ioAnomaly,
                title: "\(process.displayName) is \(metric) more than usual",
                description: "Disk \(metric) is \(sigma)× the standard deviation above its normal baseline (\(score.sampleCount) samples). \(context)",
                recommendation: contextRecommendation(knowledge: knowledge),
                affectedProcess: process.displayName,
                affectedPid: process.pid
            )
        }
    }

    private func contextForAnomaly(knowledge: ProcessKnowledge, metric: String) -> String {
        switch knowledge.category {
        case .storage:
            return "This is a storage-related process, so bursts of activity can happen during indexing, backups, or large file operations."
        case .cloud:
            return "This is a sync process. High activity often means a large sync is in progress — new photos uploading, iCloud Drive changes, etc."
        case .appStore:
            return "This could indicate an app update or download is in progress."
        case .security:
            return "Security processes occasionally do intensive scans. This is usually normal but worth noting."
        default:
            return "This is outside the normal range for this process."
        }
    }

    private func contextRecommendation(knowledge: ProcessKnowledge) -> String {
        switch knowledge.category {
        case .storage:
            return "Usually resolves on its own. If it persists for hours, the process might be stuck."
        case .cloud:
            return "Check if you recently added or changed many files. Large syncs can take time."
        case .security:
            return "Let it finish. Security scans protect your Mac."
        default:
            return "Monitor it — if the activity drops back to normal shortly, it was likely a burst. If it persists, it may warrant investigation."
        }
    }

    // MARK: - Check: High Energy Consumers

    private func checkHighEnergy() -> [Finding] {
        // Find processes using disproportionate energy
        let sorted = processes.sorted { $0.energyNanojoules > $1.energyNanojoules }
        guard let top = sorted.first, top.energyNanojoules > 0 else { return [] }

        // Only flag if the top process is consuming >50% of total energy
        let totalEnergy = processes.reduce(0.0) { $0 + Double($1.energyNanojoules) }
        guard totalEnergy > 0 else { return [] }

        let topShare = Double(top.energyNanojoules) / totalEnergy

        guard topShare > 0.5 else { return [] }

        let knowledge = ProcessDatabase.lookup(top.displayName)
        let percentage = Int(topShare * 100)

        return [Finding(
            id: "high-energy-\(top.pid)",
            severity: .info,
            check: .highEnergy,
            title: "\(top.displayName) is using \(percentage)% of system energy",
            description: "This process is consuming a disproportionate share of your Mac's energy budget. \(knowledge.map { "As a \($0.category.rawValue) process, " } ?? "")this may affect battery life on a laptop.",
            recommendation: "If you're on battery power and want to extend battery life, consider whether this process needs to be running right now.",
            affectedProcess: top.displayName,
            affectedPid: top.pid
        )]
    }

    // MARK: - Check: Phantom Processes

    private func checkPhantomProcesses() -> [Finding] {
        // Processes with no known path AND not in our database.
        // Skip low PIDs and processes with no memory usage — those are typically
        // privileged system processes we can't fully inspect.
        processes.compactMap { process -> Finding? in
            guard process.path == nil,
                  ProcessDatabase.lookup(process.displayName) == nil,
                  process.pid > 100, // Low PIDs are almost always system daemons
                  process.memoryBytes > 0 // Skip processes we can't inspect at all
            else { return nil }

            // Only flag if the process has meaningful activity
            guard process.memoryBytes > 10_000_000 || // >10MB memory
                  (ioRates[process.pid].map { $0.readBytesPerSec + $0.writeBytesPerSec > 10_000 } ?? false)
            else { return nil }

            return Finding(
                id: "phantom-\(process.pid)",
                severity: .info,
                check: .phantomProcess,
                title: "Can't determine what \"\(process.displayName)\" is",
                description: "This process has no executable path that Vigil can read, and it's not in the known process database. It's using \(ByteCountFormatter.string(fromByteCount: Int64(process.memoryBytes), countStyle: .memory)) of memory.",
                recommendation: "This sometimes happens with system helper processes or processes running under a different user. If the name looks unfamiliar, it may be worth looking into.",
                affectedProcess: process.displayName,
                affectedPid: process.pid
            )
        }
    }

    // MARK: - Health Score

    private func computeHealthScore(findings: [Finding]) -> Int {
        var score = 100
        for finding in findings {
            switch finding.severity {
            case .critical: score -= 15
            case .warning: score -= 8
            case .info: score -= 2
            }
        }
        return max(0, min(100, score))
    }

    // MARK: - Passed Checks

    private func generatePassedChecks(findings: [Finding]) -> [PassedCheck] {
        let activeChecks = Set(findings.map(\.check))
        return Check.allCases.compactMap { check in
            guard !activeChecks.contains(check) else { return nil }
            return PassedCheck(check: check, message: check.passedMessage)
        }
    }
}

// MARK: - Data Types

struct HeuristicsResult {
    let healthScore: Int
    let totalProcesses: Int
    let knownProcesses: Int
    let unknownProcesses: Int
    let findings: [Finding]
    let passedChecks: [PassedCheck]

    var healthLevel: HealthLevel {
        switch healthScore {
        case 90...100: .good
        case 70..<90: .fair
        case 50..<70: .concerning
        default: .poor
        }
    }

    enum HealthLevel: String {
        case good = "Good"
        case fair = "Fair"
        case concerning = "Concerning"
        case poor = "Poor"
    }
}

struct Finding: Identifiable {
    let id: String
    let severity: Severity
    let check: Check
    let title: String
    let description: String
    let recommendation: String
    let affectedProcess: String
    let affectedPid: Int32?

    enum Severity: Int, Comparable {
        case info = 0
        case warning = 1
        case critical = 2

        static func < (lhs: Severity, rhs: Severity) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}

enum Check: String, CaseIterable {
    case unknownHighIO = "Unknown Process I/O"
    case missingEssential = "Essential Processes"
    case expectationViolation = "Process Lifetime"
    case ioAnomaly = "I/O Baseline"
    case highEnergy = "Energy Usage"
    case phantomProcess = "Process Identity"

    var passedMessage: String {
        switch self {
        case .unknownHighIO: "No unrecognized processes with high disk activity"
        case .missingEssential: "All essential system processes are running"
        case .expectationViolation: "No processes running outside their expected lifetime"
        case .ioAnomaly: "All monitored processes are within their I/O baselines"
        case .highEnergy: "No single process is dominating energy usage"
        case .phantomProcess: "All active processes have verifiable executable paths"
        }
    }
}

struct PassedCheck: Identifiable {
    let check: Check
    let message: String
    var id: String { check.rawValue }
}
