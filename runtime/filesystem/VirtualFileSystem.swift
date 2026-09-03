import Foundation

final class VirtualFileSystem {
    static let shared = VirtualFileSystem()
    
    private let fileManager = FileManager.default
    
    var rootURL: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("RustForge", isDirectory: true)
    }
    
    private init() {
        ensureDirectories()
    }
    
    private func ensureDirectories() {
        let dirs = ["projects", "toolchains", "cargo/registry", "cargo/git", "cargo/cache", "sdk", "tmp"]
        for dir in dirs {
            let url = rootURL.appendingPathComponent(dir, isDirectory: true)
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
    
    func resolve(_ relativePath: String) -> URL {
        rootURL.appendingPathComponent(relativePath)
    }
    
    func exists(_ relativePath: String) -> Bool {
        fileManager.fileExists(atPath: resolve(relativePath).path)
    }
    
    func readText(_ relativePath: String) -> String? {
        try? String(contentsOf: resolve(relativePath), encoding: .utf8)
    }
    
    func writeText(_ content: String, to relativePath: String) -> Bool {
        let url = resolve(relativePath)
        try? fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }
    
    func readData(_ relativePath: String) -> Data? {
        try? Data(contentsOf: resolve(relativePath))
    }
    
    func writeData(_ data: Data, to relativePath: String) -> Bool {
        let url = resolve(relativePath)
        try? fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        do {
            try data.write(to: url)
            return true
        } catch {
            return false
        }
    }
    
    func listDirectory(_ relativePath: String) -> [String] {
        let url = resolve(relativePath)
        guard let contents = try? fileManager.contentsOfDirectory(atPath: url.path) else { return [] }
        return contents.sorted()
    }
    
    func wasiPreopens() -> [(guestPath: String, hostPath: String)] {
        [
            ("/", rootURL.path),
            ("/projects", resolve("projects").path),
            ("/tmp", resolve("tmp").path),
            ("/cargo", resolve("cargo").path)
        ]
    }
}
