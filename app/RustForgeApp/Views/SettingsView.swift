import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSDKImporter = false
    @State private var sdkAlert: String?
    @State private var isImportingSDK = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Toolchain") {
                    Stepper("Workers del compilador: \(appState.settings.maxCompilerWorkers)",
                            value: $appState.settings.maxCompilerWorkers, in: 1...2)
                    Stepper("Jobs de Cargo: \(appState.settings.cargoParallelJobs)",
                            value: $appState.settings.cargoParallelJobs, in: 1...2)
                    HStack {
                        Text("Límite memoria WASM")
                        Spacer()
                        TextField("MB", value: $appState.settings.wasmMemoryLimitMB, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("MB").foregroundStyle(.secondary)
                    }
                    Toggle("Habilitar AOT (experimental)", isOn: $appState.settings.enableAOT)
                }

                Section("Cache y Offline") {
                    HStack {
                        Text("Tamaño máximo cache")
                        Spacer()
                        TextField("MB", value: $appState.settings.cargoCacheSizeMB, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("MB")
                    }
                    Toggle("Modo offline", isOn: $appState.settings.offlineMode)
                    let stats = CargoCache.shared.stats()
                    LabeledContent("Cache actual", value: stats.formattedTotal)
                    Button("Limpiar cache de Cargo", role: .destructive) {
                        try? CargoCache.shared.clearAll()
                    }
                }

                Section {
                    SecureField("GitHub Token (classic o fine-grained)", text: $appState.settings.githubToken)
                    TextField("Repositorio (owner/repo)", text: $appState.settings.githubRepo)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Workflow file", text: $appState.settings.githubWorkflowFile)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if appState.settings.githubRepo.isEmpty {
                        Button("Usar este repo (espinosalastresr-del/rustforge-ios)") {
                            appState.settings.githubRepo = "espinosalastresr-del/rustforge-ios"
                            appState.settings.githubWorkflowFile = "build.yml"
                        }
                    }
                } header: {
                    Text("GitHub Actions")
                } footer: {
                    Text("Necesario para generar el .ipa. Token con permisos repo + workflow. Luego instala el IPA con LiveContainer.")
                }

                Section {
                    if appState.settings.sdkPath.isEmpty {
                        Text("Ningún SDK importado")
                            .foregroundStyle(.secondary)
                    } else {
                        LabeledContent("Ruta") {
                            Text(appState.settings.sdkPath)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        LabeledContent("Versión", value: appState.settings.sdkVersion.isEmpty ? "—" : appState.settings.sdkVersion)
                    }

                    Button {
                        showSDKImporter = true
                    } label: {
                        if isImportingSDK {
                            ProgressView()
                        } else {
                            Label("Importar SDK…", systemImage: "folder.badge.plus")
                        }
                    }
                    .disabled(isImportingSDK)

                    if !appState.settings.sdkPath.isEmpty {
                        Button("Quitar SDK", role: .destructive) {
                            try? SDKManager.shared.clearSDK()
                            appState.settings.sdkPath = ""
                            appState.settings.sdkVersion = ""
                        }
                    }

                    TextField("Deployment Target", text: $appState.settings.deploymentTarget)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("SDK de Apple")
                } footer: {
                    Text("Selecciona una carpeta iPhoneOS.sdk (o un directorio que la contenga). Se copia al sandbox de la app para el toolchain local.")
                }

                Section("Editor") {
                    HStack {
                        Text("Tamaño de fuente")
                        Slider(value: $appState.settings.fontSize, in: 11...22, step: 1)
                        Text("\(Int(appState.settings.fontSize))").frame(width: 30)
                    }
                    Toggle("Números de línea", isOn: $appState.settings.showLineNumbers)
                    Stepper("Tab size: \(appState.settings.tabSize)", value: $appState.settings.tabSize, in: 2...8)
                }

                Section("UI Builder") {
                    Picker("Framework por defecto", selection: $appState.settings.defaultUIFramework) {
                        ForEach(Settings.UIFramework.allCases, id: \.self) { fw in
                            Text(fw.rawValue).tag(fw)
                        }
                    }
                }

                Section("Acerca de") {
                    LabeledContent("Versión", value: "0.1.0")
                    LabeledContent("Runtime", value: "WAMR + JIT (LiveContainer)")
                    LabeledContent("Linking", value: "GitHub Actions → IPA")
                }
            }
            .navigationTitle("Ajustes")
            .onDisappear { appState.saveSettings() }
            .fileImporter(
                isPresented: $showSDKImporter,
                allowedContentTypes: [.folder, .directory, UTType(filenameExtension: "sdk")].compactMap { $0 },
                allowsMultipleSelection: false
            ) { result in
                handleSDKPick(result)
            }
            .alert("SDK", isPresented: Binding(
                get: { sdkAlert != nil },
                set: { if !$0 { sdkAlert = nil } }
            )) {
                Button("OK", role: .cancel) { sdkAlert = nil }
            } message: {
                Text(sdkAlert ?? "")
            }
        }
    }

    private func handleSDKPick(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            sdkAlert = "No se pudo abrir el selector: \(error.localizedDescription)"
        case .success(let urls):
            guard let url = urls.first else { return }
            isImportingSDK = true
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let info = try SDKManager.shared.importSDK(from: url)
                    DispatchQueue.main.async {
                        appState.applyImportedSDK(info)
                        isImportingSDK = false
                        sdkAlert = "SDK importado: \(info.platform) \(info.version)"
                    }
                } catch {
                    DispatchQueue.main.async {
                        isImportingSDK = false
                        sdkAlert = error.localizedDescription
                    }
                }
            }
        }
    }
}
