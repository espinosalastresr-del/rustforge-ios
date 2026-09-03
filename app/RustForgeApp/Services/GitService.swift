import Foundation

/// Operaciones Git básicas sin depender de un shell completo.
final class GitService {
    static let shared = GitService()
    
    private let fileManager = FileManager.default
    
    private init() {}
    
    enum GitError: Error, LocalizedError {
        case notARepository
        case commandFailed(String)
        case notImplemented
        
        var errorDescription: String? {
            switch self {
            case .notARepository: return "No es un repositorio Git"
            case .commandFailed(let msg): return msg
            case .notImplemented: return "Operación aún no implementada"
            }
        }
    }
    
    func isRepository(at path: String) -> Bool {
        fileManager.fileExists(atPath: (path as NSString).appendingPathComponent(".git"))
    }
    
    func status(at path: String) throws -> String {
        guard isRepository(at: path) else { throw GitError.notARepository }
        return "Git status: (stub) working tree clean"
    }
    
    func currentBranch(at path: String) throws -> String {
        guard isRepository(at: path) else { throw GitError.notARepository }
        let headPath = (path as NSString).appendingPathComponent(".git/HEAD")
        guard let head = try? String(contentsOfFile: headPath, encoding: .utf8) else {
            return "unknown"
        }
        if head.hasPrefix("ref: refs/heads/") {
            return head
                .replacingOccurrences(of: "ref: refs/heads/", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return head.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func initRepository(at path: String) throws {
        let gitDir = (path as NSString).appendingPathComponent(".git")
        try fileManager.createDirectory(atPath: gitDir, withIntermediateDirectories: true)
        try "ref: refs/heads/main\n".write(
            toFile: (gitDir as NSString).appendingPathComponent("HEAD"),
            atomically: true,
            encoding: .utf8
        )
        let refsHeads = (gitDir as NSString).appendingPathComponent("refs/heads")
        try fileManager.createDirectory(atPath: refsHeads, withIntermediateDirectories: true)
        try "Unnamed repository".write(
            toFile: (gitDir as NSString).appendingPathComponent("description"),
            atomically: true,
            encoding: .utf8
        )
        let objects = (gitDir as NSString).appendingPathComponent("objects")
        let refs = (gitDir as NSString).appendingPathComponent("refs")
        try fileManager.createDirectory(atPath: objects, withIntermediateDirectories: true)
        try fileManager.createDirectory(atPath: refs, withIntermediateDirectories: true)
    }
    
    func clone(url: String, to path: String) throws {
        throw GitError.notImplemented
    }
    
    func addAll(at path: String) throws {
        guard isRepository(at: path) else { throw GitError.notARepository }
        throw GitError.notImplemented
    }
    
    func commit(message: String, at path: String) throws {
        guard isRepository(at: path) else { throw GitError.notARepository }
        throw GitError.notImplemented
    }
}
