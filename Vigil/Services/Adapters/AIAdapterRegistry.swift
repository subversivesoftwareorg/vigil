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
        // Exact matches first across all adapters, then substring/prefix
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

    // MARK: - Config Discovery

    static func discoverAllConfigs() -> [AIToolConfig] {
        adapters.compactMap { $0.readConfig() }
    }

    // MARK: - Session Parsing

    static func parseAllSessions(projectFilter: String? = nil) -> [AISessionLog] {
        adapters.flatMap { $0.parseSessions(projectFilter: projectFilter) }
    }

    // MARK: - Risk Detection

    static func detectAllRisks() -> [AISecuritySignal] {
        var signals: [AISecuritySignal] = []
        for adapter in adapters {
            let config = adapter.readConfig()
            let sessions = adapter.parseSessions(projectFilter: nil)
            signals.append(contentsOf: adapter.detectRisks(sessions: sessions, config: config))
        }
        return signals.sorted { $0.severity > $1.severity }
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
