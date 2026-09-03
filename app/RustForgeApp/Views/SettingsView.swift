import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    
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
                Section("GitHub Actions") {
                    SecureField("GitHub Token", text: $appState.settings.githubToken)
                    TextField("Repositorio (usuario/repo)", text: $appState.settings.githubRepo)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Workflow", text: $appState.settings.githubWorkflowFile)
                        .textInputAutocapitalization(.never)
                }
                Section("SDK de Apple") {
                    if appState.settings.sdkPath.isEmpty {
                        Text("Ningún SDK importado").foregroundStyle(.secondary)
                    } else {
                        LabeledContent("Ruta", value: appState.settings.sdkPath)
                        LabeledContent("Versión", value: appState.settings.sdkVersion)
                    }
                    Button("Importar SDK…") {}
                    TextField("Deployment Target", text: $appState.settings.deploymentTarget)
                        .keyboardType(.decimalPad)
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
                    LabeledContent("Versión", value: "0.1.0-dev")
                    LabeledContent("Runtime", value: "WAMR + JIT")
                }
            }
            .navigationTitle("Ajustes")
        }
    }
}
