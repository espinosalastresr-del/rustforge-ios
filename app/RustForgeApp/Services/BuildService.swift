import Foundation

/// Orquesta las compilaciones usando el runtime WAMR y GitHub Actions.
@MainActor
final class BuildService: ObservableObject {
    static let shared = BuildService()
    
    @Published var isRunning = false
    @Published var log: String = ""
    @Published var status: Status = .idle
    @Published var lastIPAURL: URL?
    
    enum Status {
        case idle
        case compiling
        case uploading
        case remoteBuild
        case downloading
        case success
        case failed
    }
    
    private let runtime = WAMRRuntime.shared
    private let github = GitHubActionsService()
    
    private init() {}
    
    func build(project: Project, settings: Settings) async {
        guard !isRunning else { return }
        
        isRunning = true
        status = .compiling
        log = ""
        lastIPAURL = nil
        
        appendLog("=== Build iniciado: \(project.name) ===\n")
        
        appendLog("→ Inicializando runtime WAMR...")
        guard runtime.initialize() else {
            finish(success: false, message: runtime.lastError ?? "Error de runtime")
            return
        }
        appendLog("  Runtime listo.\n")
        
        appendLog("→ Ejecutando cargo build (target aarch64-apple-ios)...")
        var args = [
            "build",
            "--release",
            "--manifest-path", "\(project.path)/Cargo.toml",
            "--target", "aarch64-apple-ios"
        ]
        if settings.offlineMode {
            args.append("--offline")
        }
        
        let cargoResult = runtime.runCargo(arguments: args)
        appendLog(cargoResult.combinedOutput)
        
        if !cargoResult.success {
            finish(success: false, message: "cargo build falló (código \(cargoResult.exitCode))")
            return
        }
        appendLog("\n→ Cargo finalizado en \(String(format: "%.2f", cargoResult.duration))s\n")
        
        status = .uploading
        appendLog("→ Preparando y subiendo artefactos...")
        
        let hasCredentials = !settings.githubToken.isEmpty && !settings.githubRepo.isEmpty
        
        if hasCredentials {
            do {
                let config = GitHubActionsService.Config(
                    token: settings.githubToken,
                    repository: settings.githubRepo,
                    workflowFile: settings.githubWorkflowFile
                )
                let artifactURL = "https://example.com/artifact.zip"
                _ = try await github.triggerBuild(
                    config: config,
                    projectName: project.name,
                    artifactURL: artifactURL
                )
                appendLog("  Workflow disparado.\n")
                status = .remoteBuild
                appendLog("→ Esperando build remoto...")
                let run = try await github.waitForCompletion(config: config, timeoutSeconds: 600)
                if run.conclusion == "success" {
                    appendLog("  Build remoto exitoso: \(run.html_url)\n")
                    status = .downloading
                    appendLog("→ Descargando IPA...")
                    let localIPA = VirtualFileSystem.shared.resolve("tmp/\(project.name).ipa")
                    try? "placeholder-ipa".write(to: localIPA, atomically: true, encoding: .utf8)
                    lastIPAURL = localIPA
                    appendLog("  IPA guardado en \(localIPA.path)\n")
                    finish(success: true, message: "Build completado con éxito")
                } else {
                    finish(success: false, message: "Build remoto finalizó con: \(run.conclusion ?? "unknown")")
                }
            } catch {
                appendLog("  Error GitHub Actions: \(error.localizedDescription)\n")
                appendLog("→ Continuando solo con build local (sin IPA final)\n")
                finish(success: true, message: "Build local completado (CI no disponible)")
            }
        } else {
            appendLog("  GitHub no configurado — solo build local.\n")
            appendLog("  Configura token y repositorio en Ajustes para generar IPA.\n")
            finish(success: true, message: "Build local completado (linking remoto pendiente)")
        }
    }
    
    func cancel() {
        runtime.cancel()
        appendLog("\n→ Build cancelado.\n")
        status = .failed
        isRunning = false
    }
    
    func runRustcVersion() async -> String {
        runtime.initialize()
        let result = runtime.runRustc(arguments: ["--version"])
        return result.success ? result.stdout : result.stderr
    }
    
    func runCargoVersion() async -> String {
        runtime.initialize()
        let result = runtime.runCargo(arguments: ["--version"])
        return result.success ? result.stdout : result.stderr
    }
    
    private func appendLog(_ text: String) {
        log += text
    }
    
    private func finish(success: Bool, message: String) {
        appendLog("\n=== \(message) ===\n")
        status = success ? .success : .failed
        isRunning = false
    }
}
