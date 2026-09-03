import SwiftUI

struct TerminalView: View {
    @EnvironmentObject var appState: AppState
    @State private var input: String = ""
    @State private var history: [TerminalLine] = [
        TerminalLine(type: .system, text: "RustForge Terminal v0.1"),
        TerminalLine(type: .system, text: "Escribe 'help' para ver los comandos disponibles.")
    ]
    @State private var isRunningCommand = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(history) { line in
                                Text(line.text)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundStyle(line.type.color)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(line.id)
                            }
                        }.padding()
                    }
                    .onChange(of: history.count) {
                        if let last = history.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
                Divider()
                HStack(spacing: 10) {
                    Text(">").font(.system(size: 14, design: .monospaced)).foregroundStyle(.orange)
                    TextField("Comando", text: $input)
                        .font(.system(size: 14, design: .monospaced))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(isRunningCommand)
                        .onSubmit { Task { await runCommand() } }
                    if isRunningCommand { ProgressView() }
                    else {
                        Button { Task { await runCommand() } } label: { Image(systemName: "return") }
                            .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
            }
            .navigationTitle("Terminal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Limpiar") { history.removeAll() }
                }
            }
        }
    }
    
    private func runCommand() async {
        let command = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return }
        history.append(TerminalLine(type: .input, text: "> \(command)"))
        input = ""
        isRunningCommand = true
        let output = await execute(command)
        for line in output { history.append(TerminalLine(type: .output, text: line)) }
        isRunningCommand = false
    }
    
    private func execute(_ command: String) async -> [String] {
        let parts = command.split(separator: " ", maxSplits: 1).map(String.init)
        let cmd = parts.first?.lowercased() ?? ""
        let args = parts.count > 1 ? parts[1] : ""
        switch cmd {
        case "help":
            return ["Comandos: help, clear, projects, version, rustc --version, cargo --version, runtime status"]
        case "clear":
            await MainActor.run { history.removeAll() }
            return []
        case "projects":
            if appState.projects.isEmpty { return ["No hay proyectos."] }
            return appState.projects.map { "• \($0.name)  (\($0.path))" }
        case "version":
            return ["RustForge iOS 0.1.0-dev"]
        case "rustc":
            let result = await BuildService.shared.runRustcVersion()
            return result.components(separatedBy: "\n").filter { !$0.isEmpty }
        case "cargo":
            let result = await BuildService.shared.runCargoVersion()
            return result.components(separatedBy: "\n").filter { !$0.isEmpty }
        case "runtime":
            if args == "status" {
                let rt = WAMRRuntime.shared
                return ["Inicializado: \(rt.isInitialized)", "Último error: \(rt.lastError ?? "ninguno")"]
            }
            return ["Uso: runtime status"]
        default:
            return ["Comando no reconocido: \(command)"]
        }
    }
}

struct TerminalLine: Identifiable {
    let id = UUID()
    let type: LineType
    let text: String
    enum LineType {
        case system, input, output
        var color: Color {
            switch self {
            case .system: return .secondary
            case .input: return .orange
            case .output: return .primary
            }
        }
    }
}
