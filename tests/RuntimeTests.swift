import Foundation

enum RuntimeTests {
    
    static func runAll() -> [(name: String, passed: Bool, message: String)] {
        var results: [(String, Bool, String)] = []
        results.append(testInitialize())
        results.append(testRustcVersion())
        results.append(testCargoVersion())
        results.append(testCargoBuild())
        results.append(testVFS())
        results.append(testCargoCache())
        return results
    }
    
    private static func testInitialize() -> (String, Bool, String) {
        let rt = WAMRRuntime.shared
        let ok = rt.initialize()
        return ("WAMR initialize", ok, ok ? "OK" : (rt.lastError ?? "fail"))
    }
    
    private static func testRustcVersion() -> (String, Bool, String) {
        let result = WAMRRuntime.shared.runRustc(arguments: ["--version"])
        let ok = result.success && result.stdout.contains("rustc")
        return ("rustc --version", ok, result.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    private static func testCargoVersion() -> (String, Bool, String) {
        let result = WAMRRuntime.shared.runCargo(arguments: ["--version"])
        let ok = result.success && result.stdout.contains("cargo")
        return ("cargo --version", ok, result.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    private static func testCargoBuild() -> (String, Bool, String) {
        let result = WAMRRuntime.shared.runCargo(arguments: [
            "build", "--release", "--target", "aarch64-apple-ios"
        ])
        let ok = result.success && result.stdout.contains("Finished")
        return ("cargo build --release", ok, result.success ? "Finished OK" : result.stderr)
    }
    
    private static func testVFS() -> (String, Bool, String) {
        let vfs = VirtualFileSystem.shared
        let preopens = vfs.wasiPreopens()
        let ok = !preopens.isEmpty
        return ("VFS preopens", ok, "\(preopens.count) preopens")
    }
    
    private static func testCargoCache() -> (String, Bool, String) {
        let stats = CargoCache.shared.stats()
        return ("CargoCache stats", true, stats.formattedTotal)
    }
}
