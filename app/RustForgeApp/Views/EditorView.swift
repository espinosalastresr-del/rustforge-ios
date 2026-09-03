import SwiftUI

struct EditorView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var buildService = BuildService.shared
    @State private var fileContent: String = ""
    @State private var isEditing = false
    @State private var showBuildSheet = false
    
    var body: some View {
        NavigationStack {
            Group {
                if let project = appState.selectedProject {
                    HStack(spacing: 0) {
                        FileTreeView(project: project)
                            .frame(width: 260)
                        Divider()
                        editorArea
                    }
                } else {
                    noProjectSelected
                }
            }
            .navigationTitle(appState.selectedProject?.name ?? "Editor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if appState.selectedFile != nil {
                        Button { saveCurrentFile() } label: {
                            Image(systemName: "square.and.arrow.down")
                        }
                        .disabled(!isEditing)
                    }
                    Button {
                        Task { await startBuild() }
                    } label: {
                        if buildService.isRunning { ProgressView() }
                        else { Image(systemName: "play.fill") }
                    }
                    .disabled(appState.selectedProject == nil || buildService.isRunning)
                }
            }
            .onChange(of: appState.selectedFile) { _, newFile in loadFile(newFile) }
            .sheet(isPresented: $showBuildSheet) {
                BuildLogView(buildService: buildService)
            }
        }
    }
    
    private var noProjectSelected: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass").font(.system(size: 56)).foregroundStyle(.secondary)
            Text("Ningún proyecto seleccionado").font(.title2.bold())
            Text("Selecciona o crea un proyecto en la pestaña Proyectos")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.padding()
    }
    
    private var editorArea: some View {
        Group {
            if let file = appState.selectedFile, !file.isDirectory {
                VStack(spacing: 0) {
                    HStack {
                        Text(file.name).font(.subheadline.weight(.medium)).padding(.horizontal, 12).padding(.vertical, 8)
                        Spacer()
                        if isEditing {
                            Text("Modificado").font(.caption).foregroundStyle(.orange).padding(.trailing, 12)
                        }
                    }.background(Color(.secondarySystemBackground))
                    TextEditor(text: $fileContent)
                        .font(.system(size: appState.settings.fontSize, design: .monospaced))
                        .onChange(of: fileContent) { _, _ in isEditing = true }
                        .scrollContentBackground(.hidden)
                        .padding(8)
                }
            } else {
                ContentUnavailableView("Selecciona un archivo", systemImage: "doc",
                    description: Text("Elige un archivo del árbol para editarlo"))
            }
        }
    }
    
    private func loadFile(_ file: ProjectFile?) {
        guard let file, !file.isDirectory else { fileContent = ""; isEditing = false; return }
        fileContent = ProjectFileManager.shared.readFile(at: file.path) ?? ""
        isEditing = false
    }
    
    private func saveCurrentFile() {
        guard let file = appState.selectedFile else { return }
        if ProjectFileManager.shared.writeFile(content: fileContent, at: file.path) { isEditing = false }
    }
    
    private func startBuild() async {
        guard let project = appState.selectedProject else { return }
        showBuildSheet = true
        await buildService.build(project: project, settings: appState.settings)
    }
}

struct FileTreeView: View {
    let project: Project
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        List {
            OutlineGroup(project.files, children: \.children) { file in
                Button {
                    if !file.isDirectory { appState.selectedFile = file }
                } label: {
                    Label {
                        Text(file.name).font(.subheadline)
                            .foregroundStyle(appState.selectedFile?.id == file.id ? .orange : .primary)
                    } icon: {
                        Image(systemName: iconName(for: file)).foregroundStyle(iconColor(for: file))
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
    
    private func iconName(for file: ProjectFile) -> String {
        if file.isDirectory { return "folder.fill" }
        if file.isRustFile { return "chevron.left.forwardslash.chevron.right" }
        if file.isSwiftFile { return "swift" }
        if file.isTomlFile { return "doc.text" }
        return "doc"
    }
    
    private func iconColor(for file: ProjectFile) -> Color {
        if file.isDirectory { return .blue }
        if file.isRustFile { return .orange }
        if file.isSwiftFile { return .red }
        return .secondary
    }
}
