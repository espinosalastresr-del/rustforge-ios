import Foundation

/// Runtime principal basado en WAMR.
/// Mientras el bridge nativo no esté linkado, opera en modo simulación controlada.
final class WAMRRuntime {
    static let shared = WAMRRuntime()
    
    private(set) var isInitialized = false
    private(set) var lastError: String?
    private var modules: [UUID: LoadedModule] = [:]
    
    private init() {}
    
    struct LoadedModule {
        let id: UUID
        let name: String
        let path: String
        var isInstantiated: Bool
    }
    
    @discardableResult
    func initialize() -> Bool {
        guard !isInitialized else { return true }
        isInitialized = true
        lastError = nil
        print("[WAMR] Runtime inicializado (modo: \(bridgeAvailable ? "nativo" : "simulación"))")
        return true
    }
    
    func destroy() {
        for module in modules.values {
            unloadModule(module.id)
        }
        modules.removeAll()
        isInitialized = false
    }
    
    @discardableResult
    func loadModule(path: String, name: String) -> UUID? {
        guard isInitialized else {
            lastError = "Runtime no inicializado. Llama a initialize() primero."
            return nil
        }
        let id = UUID()
        modules[id] = LoadedModule(id: id, name: name, path: path, isInstantiated: true)
        return id
    }
    
    func unloadModule(_ id: UUID) {
        modules.removeValue(forKey: id)
    }
    
    func execute(moduleId: UUID, environment: WASIEnvironment) -> ProcessResult {
        guard isInitialized else { return .failure("Runtime no inicializado") }
        guard let module = modules[moduleId] else { return .failure("Módulo no encontrado") }
        let start = Date()
        let result = simulateExecution(module: module, environment: environment)
        return ProcessResult(
            exitCode: result.exitCode,
            stdout: result.stdout,
            stderr: result.stderr,
            duration: Date().timeIntervalSince(start)
        )
    }
    
    func runRustc(arguments: [String]) -> ProcessResult {
        guard initialize() else { return .failure(lastError ?? "No se pudo inicializar el runtime") }
        guard let moduleId = loadModule(path: "toolchains/rustc.wasm", name: "rustc") else {
            return .failure(lastError ?? "No se pudo cargar rustc.wasm")
        }
        defer { unloadModule(moduleId) }
        return execute(moduleId: moduleId, environment: WASIEnvironment.default(arguments: ["rustc"] + arguments))
    }
    
    func runCargo(arguments: [String]) -> ProcessResult {
        guard initialize() else { return .failure(lastError ?? "No se pudo inicializar el runtime") }
        guard let moduleId = loadModule(path: "toolchains/cargo.wasm", name: "cargo") else {
            return .failure(lastError ?? "No se pudo cargar cargo.wasm")
        }
        defer { unloadModule(moduleId) }
        return execute(moduleId: moduleId, environment: WASIEnvironment.default(arguments: ["cargo"] + arguments))
    }
    
    func cancel() {
        print("[WAMR] Cancel solicitado")
    }
    
    private var bridgeAvailable: Bool { false }
    
    private func simulateExecution(
        module: LoadedModule,
        environment: WASIEnvironment
    ) -> (exitCode: Int32, stdout: String, stderr: String) {
        if module.name == "rustc" {
            if environment.arguments.contains("--version") {
                return (0, "rustc 1.82.0-wamr (simulated)\nbinary: rustc.wasm\n", "")
            }
            return (0, "[rustc] Compilación simulada completada.\n", "")
        }
        if module.name == "cargo" {
            if environment.arguments.contains("--version") {
                return (0, "cargo 1.82.0-wamr (simulated)\n", "")
            }
            if environment.arguments.contains("build") {
                let release = environment.arguments.contains("--release")
                let target = "aarch64-apple-ios"
                let profile = release ? "release" : "dev"
                return (0, """
                    Compiling package...
                        Finished `\(profile)` profile [optimized] target(s) in 1.84s (simulated)
                        Target: \(target)
                        Output: target/\(target)/\(release ? "release" : "debug")/libpackage.a
                    """, "")
            }
            return (0, "[cargo] Comando simulado ejecutado.\n", "")
        }
        return (0, "[WAMR] Ejecutado: \(module.name)\n", "")
    }
}
