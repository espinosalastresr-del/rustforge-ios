import Foundation

/// Orquesta compilaciones locales (WAMR) + linking/packaging en GitHub Actions.
@MainActor
final class BuildService: ObservableObject {
    static let shared = BuildService()

    @Published var isRunning = false
    @Published var log: String = ""
    @Published var status: Status = .idle
    @Published var lastIPAURL: URL?
    @Published var lastRunURL: String?

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
        lastRunURL = nil

        appendLog("=== Build iniciado: \(project.name) ===\n")

        // 1) Local WAMR / cargo (best-effort; stub runtime may no-op)
        appendLog("→ Inicializando runtime WAMR...")
        if runtime.initialize() {
            appendLog("  Runtime listo.\n")
            appendLog("→ Ejecutando cargo build (target aarch64-apple-ios)...")
            var args = [
                "build", "--release",
                "--manifest-path", "\(project.path)/Cargo.toml",
                "--target", "aarch64-apple-ios"
            ]
            if settings.offlineMode { args.append("--offline") }
            let cargoResult = runtime.runCargo(arguments: args)
            appendLog(cargoResult.combinedOutput)
            if cargoResult.success {
                appendLog("\n→ Cargo local finalizado en \(String(format: "%.2f", cargoResult.duration))s\n")
            } else {
                appendLog("\n→ Cargo local no disponible o falló — se usará CI remoto.\n")
            }
        } else {
            appendLog("  Runtime no disponible (\(runtime.lastError ?? "unknown")). Continuando con CI.\n")
        }

        // 2) GitHub Actions remote link + IPA
        let hasCredentials = !settings.githubToken.isEmpty && !settings.githubRepo.isEmpty
        guard hasCredentials else {
            appendLog("\n⚠ GitHub no configurado.\n")
            appendLog("  Ve a Ajustes → GitHub Actions y configura:\n")
            appendLog("  • Token (scope: repo, workflow)\n")
            appendLog("  • Repositorio: usuario/rustforge-ios\n")
            appendLog("  • Workflow: build.yml\n")
            finish(success: false, message: "Configura GitHub en Ajustes para generar el IPA")
            return
        }

        status = .uploading
        appendLog("→ Disparando GitHub Actions (Build iOS App)...\n")

        let config = GitHubActionsService.Config(
            token: settings.githubToken,
            repository: settings.githubRepo,
            workflowFile: settings.githubWorkflowFile.isEmpty ? "build.yml" : settings.githubWorkflowFile
        )

        do {
            // use_template=true: CI genera hybrid demo; cuando haya host de artefactos se pasa artifact_url
            try await github.triggerBuild(
                config: config,
                projectName: project.name.replacingOccurrences(of: " ", with: ""),
                artifactURL: "",
                useTemplate: true
            )
            appendLog("  Workflow disparado.\n")

            status = .remoteBuild
            appendLog("→ Esperando build remoto (puede tardar 1–3 min)...\n")

            let run = try await github.waitForCompletion(config: config, timeoutSeconds: 900)
            lastRunURL = run.html_url
            appendLog("  Run: \(run.html_url)\n")
            appendLog("  Conclusión: \(run.conclusion ?? "?")\n")

            guard run.conclusion == "success" else {
                finish(success: false, message: "Build remoto finalizó con: \(run.conclusion ?? "unknown")")
                return
            }

            status = .downloading
            appendLog("→ Descargando IPA...\n")

            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let outDir = docs.appendingPathComponent("RustForge/builds", isDirectory: true)
            let ipa = try await github.downloadIPA(
                config: config,
                runId: run.id,
                projectName: project.name.replacingOccurrences(of: " ", with: ""),
                destinationDirectory: outDir
            )
            lastIPAURL = ipa
            appendLog("  IPA guardado: \(ipa.path)\n")
            appendLog("  Listo para instalar con LiveContainer.\n")
            finish(success: true, message: "Build completado — IPA listo")
        } catch {
            appendLog("  Error: \(error.localizedDescription)\n")
            finish(success: false, message: "Error en CI: \(error.localizedDescription)")
        }
    }

    func cancel() {
        runtime.cancel()
        appendLog("\n→ Build cancelado por el usuario.\n")
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
