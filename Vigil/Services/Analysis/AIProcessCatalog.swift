import Foundation

/// Identifies AI-related processes and file paths for the AI Activity view.
///
/// Tracks three categories of AI tooling:
/// - Coding assistants: Claude Code, Codex, Copilot, Aider, Cursor
/// - Chat/desktop apps: ChatGPT, Claude Desktop, Gemini
/// - Local model runners: Ollama, LM Studio, llama.cpp, MLX
///
/// Also identifies AI-related file activity by path patterns (model downloads,
/// AI workspace files, provider data directories).
enum AIProcessCatalog {

    /// Known AI-related process name patterns and their metadata.
    static let knownProcesses: [AIProcessEntry] = [
        // Coding assistants
        AIProcessEntry(patterns: ["claude"], displayName: "Claude Code",
                       category: .codingAssistant, provider: "Anthropic"),
        AIProcessEntry(patterns: ["codex"], displayName: "Codex CLI",
                       category: .codingAssistant, provider: "OpenAI"),
        AIProcessEntry(patterns: ["copilot"], displayName: "GitHub Copilot",
                       category: .codingAssistant, provider: "GitHub/OpenAI"),
        AIProcessEntry(patterns: ["aider"], displayName: "Aider",
                       category: .codingAssistant, provider: "Open Source"),
        AIProcessEntry(patterns: ["cursor", "Cursor"], displayName: "Cursor",
                       category: .codingAssistant, provider: "Cursor Inc"),
        AIProcessEntry(patterns: ["windsurf", "Windsurf"], displayName: "Windsurf",
                       category: .codingAssistant, provider: "Codeium"),
        AIProcessEntry(patterns: ["zed", "Zed"], displayName: "Zed",
                       category: .codingAssistant, provider: "Zed Industries"),

        // Chat / desktop apps
        AIProcessEntry(patterns: ["ChatGPT"], displayName: "ChatGPT",
                       category: .chatApp, provider: "OpenAI"),
        AIProcessEntry(patterns: ["Claude"], displayName: "Claude Desktop",
                       category: .chatApp, provider: "Anthropic"),
        AIProcessEntry(patterns: ["Gemini"], displayName: "Gemini",
                       category: .chatApp, provider: "Google"),

        // Local model runners
        AIProcessEntry(patterns: ["ollama"], displayName: "Ollama",
                       category: .localModel, provider: "Local"),
        AIProcessEntry(patterns: ["LM Studio", "lmstudio"], displayName: "LM Studio",
                       category: .localModel, provider: "Local"),
        AIProcessEntry(patterns: ["llama", "llamafile"], displayName: "llama.cpp",
                       category: .localModel, provider: "Local"),
        AIProcessEntry(patterns: ["mlx_lm", "mlx-server", "mlx_server"], displayName: "MLX",
                       category: .localModel, provider: "Local (Apple MLX)"),
        AIProcessEntry(patterns: ["whisper"], displayName: "Whisper",
                       category: .localModel, provider: "Local"),
        AIProcessEntry(patterns: ["stable-diffusion", "DiffusionBee"], displayName: "Stable Diffusion",
                       category: .localModel, provider: "Local"),
    ]

    /// File path patterns that indicate AI-related activity.
    static let pathPatterns: [AIPathPattern] = [
        // AI tool data directories
        AIPathPattern(pattern: "/.claude/", category: .workspaceData, tool: "Claude Code"),
        AIPathPattern(pattern: "/Library/Application Support/Claude/", category: .workspaceData, tool: "Claude Desktop"),
        AIPathPattern(pattern: "/Library/Application Support/ChatGPT/", category: .workspaceData, tool: "ChatGPT"),
        AIPathPattern(pattern: "/.cursor/", category: .workspaceData, tool: "Cursor"),
        AIPathPattern(pattern: "/.codex/", category: .workspaceData, tool: "Codex"),
        AIPathPattern(pattern: "/.aider", category: .workspaceData, tool: "Aider"),
        AIPathPattern(pattern: "/.continue/", category: .workspaceData, tool: "Continue"),
        AIPathPattern(pattern: "/copilot", category: .workspaceData, tool: "GitHub Copilot"),

        // Model storage
        AIPathPattern(pattern: "/.ollama/", category: .modelStorage, tool: "Ollama"),
        AIPathPattern(pattern: "/LM Studio/", category: .modelStorage, tool: "LM Studio"),
        AIPathPattern(pattern: "/huggingface/", category: .modelStorage, tool: "Hugging Face"),
        AIPathPattern(pattern: "/.cache/huggingface/", category: .modelStorage, tool: "Hugging Face"),
        AIPathPattern(pattern: "/mlx-models/", category: .modelStorage, tool: "MLX"),

    ]

    /// File extensions that are commonly model files.
    static let modelFileExtensions: Set<String> = [
        "gguf", "ggml", "safetensors", "bin", "onnx", "mlmodel",
        "mlpackage", "pt", "pth", "h5", "tflite", "mlmodelc"
    ]

    /// Check if a process name matches any known AI process.
    /// Two-pass matching: exact name match (high confidence) then substring (medium confidence).
    /// Case-sensitive to distinguish e.g. "claude" (CLI) from "Claude" (Desktop app).
    static func match(_ processName: String) -> ProcessMatch? {
        // Pass 1: exact match → observed, high confidence
        for entry in knownProcesses {
            for pattern in entry.patterns {
                if processName == pattern {
                    return ProcessMatch(
                        entry: entry,
                        evidence: AIEvidence(
                            basis: .observed,
                            confidence: .high,
                            reason: "Process name exactly matches known pattern \"\(pattern)\""
                        )
                    )
                }
            }
        }

        // Pass 2: substring match → inferred, medium confidence
        for entry in knownProcesses {
            for pattern in entry.patterns {
                if processName.contains(pattern) {
                    return ProcessMatch(
                        entry: entry,
                        evidence: AIEvidence(
                            basis: .inferred,
                            confidence: .medium,
                            reason: "Process name contains \"\(pattern)\" — may be \(entry.displayName) or a related process"
                        )
                    )
                }
            }
        }

        return nil
    }

    /// Check if a file path matches any known AI path pattern.
    /// All path matches are inferred — we see a file change in an AI-related directory
    /// but cannot prove which process caused it.
    static func matchPath(_ path: String) -> PathMatch? {
        let lower = path.lowercased()
        guard let pattern = pathPatterns.first(where: { lower.contains($0.pattern.lowercased()) }) else {
            return nil
        }

        let confidence: ConfidenceLevel =
            pattern.pattern.hasPrefix("/.") || pattern.pattern.contains("Application Support")
            ? .high : .medium

        return PathMatch(
            pattern: pattern,
            evidence: AIEvidence(
                basis: .inferred,
                confidence: confidence,
                reason: "File path contains \"\(pattern.pattern)\" — likely \(pattern.tool) activity"
            )
        )
    }

    /// Check if a file path looks like a model file.
    static func isModelFile(_ path: String) -> Bool {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        return modelFileExtensions.contains(ext)
    }
}

// MARK: - Evidence Model

struct AIEvidence {
    let basis: EvidenceBasis
    let confidence: ConfidenceLevel
    let reason: String
}

enum EvidenceBasis: String {
    case observed
    case inferred
    case configured

    var rank: Int {
        switch self {
        case .observed: 2
        case .configured: 1
        case .inferred: 0
        }
    }
}

enum ConfidenceLevel: Int, Comparable {
    case low = 0
    case medium = 1
    case high = 2

    static func < (lhs: ConfidenceLevel, rhs: ConfidenceLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct ProcessMatch {
    let entry: AIProcessEntry
    let evidence: AIEvidence
}

struct PathMatch {
    let pattern: AIPathPattern
    let evidence: AIEvidence
}

// MARK: - Data Types

struct AIProcessEntry {
    let patterns: [String]
    let displayName: String
    let category: AICategory
    let provider: String
}

struct AIPathPattern {
    let pattern: String
    let category: AIPathCategory
    let tool: String
}

enum AICategory: String, CaseIterable {
    case codingAssistant = "Coding Assistant"
    case chatApp = "Chat / Desktop App"
    case localModel = "Local Model Runner"

    var systemImage: String {
        switch self {
        case .codingAssistant: "chevron.left.forwardslash.chevron.right"
        case .chatApp: "bubble.left.and.bubble.right"
        case .localModel: "cpu"
        }
    }
}

enum AIPathCategory: String {
    case workspaceData = "Workspace Data"
    case modelStorage = "Model Storage"
}
