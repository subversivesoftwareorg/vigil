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

    // MARK: - Cached Aggregate Queries

    static func discoverAllConfigs() -> [AIToolConfig] {
        Cache.shared.configs()
    }

    /// Sessions grouped by the toolID of the adapter that parsed them.
    /// This is the primary cached structure — use it whenever session→tool
    /// attribution is needed, instead of re-parsing to match IDs.
    static func parseAllSessionsByTool() -> [String: [AISessionLog]] {
        Cache.shared.sessionsByTool()
    }

    static func parseAllSessions(projectFilter: String? = nil) -> [AISessionLog] {
        if projectFilter != nil {
            return adapters.flatMap { $0.parseSessions(projectFilter: projectFilter) }
        }
        return Cache.shared.sessionsByTool().values.flatMap { $0 }
    }

    static func detectAllRisks() -> [AISecuritySignal] {
        Cache.shared.risks()
    }

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

    /// Time-based cache for the registry's expensive aggregate queries.
    ///
    /// Locking rule: the lock is ONLY held to read or write cached values —
    /// never while computing them. Computation calls back into adapter code
    /// (readConfig → discoverProjectRoots → projectRoots(marker:)), so holding
    /// the lock across a compute would self-deadlock on this non-reentrant lock.
    /// The tradeoff is that two threads racing on a cold cache may both compute;
    /// the result is identical and the second write is a harmless overwrite.
    final class Cache: @unchecked Sendable {
        static let shared = Cache()

        private let lock = NSLock()
        private let ttl: TimeInterval = 30

        private var cachedConfigs: (value: [AIToolConfig], at: Date)?
        private var cachedSessionsByTool: (value: [String: [AISessionLog]], at: Date)?
        private var cachedRisks: (value: [AISecuritySignal], at: Date)?
        private var cachedRoots: [String: (value: [String], at: Date)] = [:]

        // MARK: Configs

        func configs() -> [AIToolConfig] {
            if let hit = readCache({ $0.cachedConfigs }) { return hit }
            let result = AIAdapterRegistry.adapters.compactMap { $0.readConfig() }
            writeCache { $0.cachedConfigs = (result, .now) }
            return result
        }

        // MARK: Sessions (grouped by toolID)

        func sessionsByTool() -> [String: [AISessionLog]] {
            if let hit = readCache({ $0.cachedSessionsByTool }) { return hit }
            var result: [String: [AISessionLog]] = [:]
            for adapter in AIAdapterRegistry.adapters {
                let sessions = adapter.parseSessions(projectFilter: nil)
                if !sessions.isEmpty {
                    result[adapter.toolID] = sessions
                }
            }
            writeCache { $0.cachedSessionsByTool = (result, .now) }
            return result
        }

        // MARK: Risks

        func risks() -> [AISecuritySignal] {
            if let hit = readCache({ $0.cachedRisks }) { return hit }
            // Reuse the cached configs and sessions — do not re-read per adapter
            let configs = configs()
            let byTool = sessionsByTool()
            var signals: [AISecuritySignal] = []
            for adapter in AIAdapterRegistry.adapters {
                let config = configs.first { $0.tool == adapter.displayName }
                let sessions = byTool[adapter.toolID] ?? []
                signals.append(contentsOf: adapter.detectRisks(sessions: sessions, config: config))
            }
            let result = signals.sorted { $0.severity > $1.severity }
            writeCache { $0.cachedRisks = (result, .now) }
            return result
        }

        // MARK: Project Roots

        func projectRoots(marker: String) -> [String] {
            lock.lock()
            if let cached = cachedRoots[marker], Date.now.timeIntervalSince(cached.at) < ttl {
                lock.unlock()
                return cached.value
            }
            lock.unlock()

            let result = Self.scanProjectRoots(marker: marker)

            lock.lock()
            cachedRoots[marker] = (result, .now)
            lock.unlock()
            return result
        }

        // MARK: Invalidation

        func invalidate() {
            lock.lock()
            defer { lock.unlock() }
            cachedConfigs = nil
            cachedSessionsByTool = nil
            cachedRisks = nil
            cachedRoots.removeAll()
        }

        // MARK: Lock Helpers

        private func readCache<T>(_ get: (Cache) -> (value: T, at: Date)?) -> T? {
            lock.lock()
            defer { lock.unlock() }
            guard let entry = get(self), Date.now.timeIntervalSince(entry.at) < ttl else {
                return nil
            }
            return entry.value
        }

        private func writeCache(_ set: (Cache) -> Void) {
            lock.lock()
            defer { lock.unlock() }
            set(self)
        }

        // MARK: Filesystem Scan

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
