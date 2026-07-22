import Foundation

enum AIAdapterRegistry {

    static let adapters: [any AIToolAdapter] = [
        ClaudeCodeAdapter(),
        ClaudeDesktopAdapter(),
        CodexAdapter(),
        CursorAdapter(),
        CopilotAdapter(),
        WindsurfAdapter(),
        AiderAdapter(),
        ClineRooAdapter(),
        OllamaAdapter(),
        LMStudioAdapter(),
        LlamaCppAdapter(),
        MLXAdapter(),
        HuggingFaceAdapter(),
        ChatGPTAdapter(),
        GeminiAdapter(),
        GeminiCLIAdapter(),
        ZedAdapter(),
        WhisperAdapter(),
        StableDiffusionAdapter(),
    ]

    // MARK: - Process Matching

    struct ProcessMatchResult {
        let adapter: any AIToolAdapter
        let evidence: AIEvidence
    }

    static func matchProcess(_ processName: String) -> ProcessMatchResult? {
        for mode in [ProcessSignature.MatchMode.exact, .prefix, .substring] {
            for adapter in adapters {
                for sig in adapter.processSignatures where sig.matchMode == mode {
                    if let evidence = sig.matches(processName) {
                        return ProcessMatchResult(adapter: adapter, evidence: evidence)
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Path Matching

    struct PathMatchResult {
        let adapter: any AIToolAdapter
        let signature: PathSignature
        let evidence: AIEvidence
    }

    static func matchPath(_ path: String) -> PathMatchResult? {
        for adapter in adapters {
            for sig in adapter.pathSignatures {
                if let evidence = sig.matches(path) {
                    return PathMatchResult(adapter: adapter, signature: sig, evidence: evidence)
                }
            }
        }
        return nil
    }

    // MARK: - Config Discovery (Cached)

    static func discoverAllConfigs() -> [AIToolConfig] {
        Cache.shared.configs()
    }

    // MARK: - Session Parsing (Cached)

    static func parseAllSessions(projectFilter: String? = nil) -> [AISessionLog] {
        if projectFilter != nil {
            return adapters.flatMap { $0.parseSessions(projectFilter: projectFilter) }
        }
        return Cache.shared.sessions()
    }

    // MARK: - Risk Detection (Cached)

    static func detectAllRisks() -> [AISecuritySignal] {
        Cache.shared.risks()
    }

    // MARK: - Cache Invalidation

    static func invalidateCache() {
        Cache.shared.invalidate()
    }

    // MARK: - Shared Utilities

    static let modelFileExtensions: Set<String> = [
        "gguf", "ggml", "safetensors", "bin", "onnx", "mlmodel",
        "mlpackage", "pt", "pth", "h5", "tflite", "mlmodelc"
    ]

    static func isModelFile(_ path: String) -> Bool {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        return modelFileExtensions.contains(ext)
    }

    static func discoverProjectRoots(marker: String) -> [String] {
        Cache.shared.projectRoots(marker: marker)
    }
}

// MARK: - Cache

extension AIAdapterRegistry {

    final class Cache: @unchecked Sendable {
        static let shared = Cache()

        private let lock = NSLock()
        private let ttl: TimeInterval = 30

        private var cachedConfigs: [AIToolConfig]?
        private var configsTimestamp: Date = .distantPast

        private var cachedSessions: [AISessionLog]?
        private var sessionsTimestamp: Date = .distantPast

        private var cachedRisks: [AISecuritySignal]?
        private var risksTimestamp: Date = .distantPast

        private var cachedProjectRoots: [String: [String]] = [:]
        private var projectRootsTimestamp: Date = .distantPast

        func configs() -> [AIToolConfig] {
            lock.lock()
            defer { lock.unlock() }
            if let cached = cachedConfigs, Date.now.timeIntervalSince(configsTimestamp) < ttl {
                return cached
            }
            let result = adapters.compactMap { $0.readConfig() }
            cachedConfigs = result
            configsTimestamp = .now
            return result
        }

        func sessions() -> [AISessionLog] {
            lock.lock()
            defer { lock.unlock() }
            if let cached = cachedSessions, Date.now.timeIntervalSince(sessionsTimestamp) < ttl {
                return cached
            }
            let result = adapters.flatMap { $0.parseSessions(projectFilter: nil) }
            cachedSessions = result
            sessionsTimestamp = .now
            return result
        }

        func risks() -> [AISecuritySignal] {
            lock.lock()
            defer { lock.unlock() }
            if let cached = cachedRisks, Date.now.timeIntervalSince(risksTimestamp) < ttl {
                return cached
            }
            var signals: [AISecuritySignal] = []
            for adapter in adapters {
                let config = adapter.readConfig()
                let adapterSessions = adapter.parseSessions(projectFilter: nil)
                signals.append(contentsOf: adapter.detectRisks(sessions: adapterSessions, config: config))
            }
            let result = signals.sorted { $0.severity > $1.severity }
            cachedRisks = result
            risksTimestamp = .now
            return result
        }

        func projectRoots(marker: String) -> [String] {
            lock.lock()
            defer { lock.unlock() }
            if let cached = cachedProjectRoots[marker],
               Date.now.timeIntervalSince(projectRootsTimestamp) < ttl {
                return cached
            }
            let result = Self.scanProjectRoots(marker: marker)
            cachedProjectRoots[marker] = result
            if cachedProjectRoots.count == 1 {
                projectRootsTimestamp = .now
            }
            return result
        }

        func invalidate() {
            lock.lock()
            defer { lock.unlock() }
            cachedConfigs = nil
            cachedSessions = nil
            cachedRisks = nil
            cachedProjectRoots.removeAll()
            projectRootsTimestamp = .distantPast
        }

        private static func scanProjectRoots(marker: String) -> [String] {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            let commonParents = [
                "\(home)/code", "\(home)/Code",
                "\(home)/Developer", "\(home)/dev",
                "\(home)/projects", "\(home)/Projects",
                "\(home)/src", "\(home)/repos",
                "\(home)/workspace", "\(home)/Workspace",
            ]

            let fm = FileManager.default
            var roots: [String] = []

            for parent in commonParents {
                guard let children = try? fm.contentsOfDirectory(atPath: parent) else { continue }
                for child in children where !child.hasPrefix(".") {
                    let projectPath = "\(parent)/\(child)"
                    var isDir: ObjCBool = false
                    guard fm.fileExists(atPath: projectPath, isDirectory: &isDir), isDir.boolValue else { continue }
                    if fm.fileExists(atPath: "\(projectPath)/\(marker)") {
                        roots.append(projectPath)
                        continue
                    }
                    guard let grandchildren = try? fm.contentsOfDirectory(atPath: projectPath) else { continue }
                    for grandchild in grandchildren where !grandchild.hasPrefix(".") {
                        let nestedPath = "\(projectPath)/\(grandchild)"
                        var nestedIsDir: ObjCBool = false
                        guard fm.fileExists(atPath: nestedPath, isDirectory: &nestedIsDir), nestedIsDir.boolValue else { continue }
                        if fm.fileExists(atPath: "\(nestedPath)/\(marker)") {
                            roots.append(nestedPath)
                        }
                    }
                }
            }

            return roots
        }
    }
}
