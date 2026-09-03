import Foundation

final class CargoCache {
    static let shared = CargoCache()
    
    private let vfs = VirtualFileSystem.shared
    private let fileManager = FileManager.default
    
    private init() {}
    
    var registryURL: URL { vfs.resolve("cargo/registry") }
    var gitURL: URL { vfs.resolve("cargo/git") }
    var cacheURL: URL { vfs.resolve("cargo/cache") }
    
    struct CacheStats {
        var registryBytes: Int64
        var gitBytes: Int64
        var cacheBytes: Int64
        var totalBytes: Int64 { registryBytes + gitBytes + cacheBytes }
        var formattedTotal: String {
            ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        }
    }
    
    func stats() -> CacheStats {
        CacheStats(
            registryBytes: directorySize(registryURL),
            gitBytes: directorySize(gitURL),
            cacheBytes: directorySize(cacheURL)
        )
    }
    
    func cratePath(name: String, version: String) -> URL {
        registryURL
            .appendingPathComponent("src")
            .appendingPathComponent("index.crates.io-standalone")
            .appendingPathComponent("\(name)-\(version)")
    }
    
    func isCached(name: String, version: String) -> Bool {
        fileManager.fileExists(atPath: cratePath(name: name, version: version).path)
    }
    
    func listCachedCrates() -> [(name: String, version: String)] {
        let src = registryURL.appendingPathComponent("src")
        guard let hosts = try? fileManager.contentsOfDirectory(atPath: src.path) else { return [] }
        var result: [(String, String)] = []
        for host in hosts {
            let hostURL = src.appendingPathComponent(host)
            guard let entries = try? fileManager.contentsOfDirectory(atPath: hostURL.path) else { continue }
            for entry in entries {
                if let idx = entry.lastIndex(of: "-") {
                    let name = String(entry[..<idx])
                    let version = String(entry[entry.index(after: idx)...])
                    result.append((name, version))
                }
            }
        }
        return result.sorted { $0.0 < $1.0 }
    }
    
    func clearRegistry() throws { try removeContents(of: registryURL) }
    func clearGit() throws { try removeContents(of: gitURL) }
    func clearAll() throws {
        try clearRegistry()
        try clearGit()
        try removeContents(of: cacheURL)
    }
    
    private func directorySize(_ url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
        ) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let size = values.fileSize else { continue }
            total += Int64(size)
        }
        return total
    }
    
    private func removeContents(of url: URL) throws {
        guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else { return }
        for item in contents {
            try fileManager.removeItem(at: item)
        }
    }
}
