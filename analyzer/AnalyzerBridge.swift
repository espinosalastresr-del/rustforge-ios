import Foundation

/// Puente hacia rust-analyzer (staticlib nativa).
final class AnalyzerBridge {
    static let shared = AnalyzerBridge()
    private(set) var isAvailable = false
    private(set) var lastError: String?
    private init() {}
    
    @discardableResult
    func initialize(projectPath: String) -> Bool {
        lastError = "rust-analyzer aún no está linkado (stub)"
        isAvailable = false
        return false
    }
    
    func shutdown() { isAvailable = false }
    
    struct Diagnostic: Identifiable {
        let id = UUID()
        let file: String
        let line: Int
        let column: Int
        let message: String
        let severity: Severity
        enum Severity { case error, warning, info, hint }
    }
    
    struct CompletionItem: Identifiable {
        let id = UUID()
        let label: String
        let kind: String
        let detail: String?
    }
    
    struct HoverInfo {
        let contents: String
        let range: Range?
        struct Range {
            let startLine: Int; let startColumn: Int
            let endLine: Int; let endColumn: Int
        }
    }
    
    func diagnostics(for filePath: String) -> [Diagnostic] { [] }
    func completions(filePath: String, line: Int, column: Int) -> [CompletionItem] { [] }
    func hover(filePath: String, line: Int, column: Int) -> HoverInfo? { nil }
    func gotoDefinition(filePath: String, line: Int, column: Int) -> (file: String, line: Int, column: Int)? { nil }
}
