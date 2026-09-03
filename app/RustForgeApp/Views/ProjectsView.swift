import SwiftUI

struct ProjectsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingNewProject = false
    @State private var newProjectName = ""
    
    var body: some View {
        NavigationStack {
            Group {
                if appState.projects.isEmpty {
                    emptyState
                } else {
                    projectList
                }
            }
            .navigationTitle("Proyectos")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNewProject = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingNewProject) {
                NavigationStack {
                    Form {
                        Section("Nuevo proyecto") {
                            TextField("Nombre del proyecto", text: $newProjectName)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                    }
                    .navigationTitle("Crear proyecto")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancelar") {
                                showingNewProject = false
                                newProjectName = ""
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Crear") {
                                createProject()
                            }
                            .disabled(newProjectName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("No hay proyectos").font(.title2.bold())
            Text("Crea tu primer proyecto Rust + SwiftUI").foregroundStyle(.secondary)
            Button {
                showingNewProject = true
            } label: {
                Label("Nuevo proyecto", systemImage: "plus").padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding()
    }
    
    private var projectList: some View {
        List {
            ForEach(appState.projects) { project in
                Button {
                    appState.openProject(project)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.title2)
                            .foregroundStyle(.orange)
                            .frame(width: 40)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(project.name).font(.headline).foregroundStyle(.primary)
                            Text(project.path).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete(perform: deleteProjects)
        }
        .listStyle(.insetGrouped)
    }
    
    private func createProject() {
        let name = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        appState.createProject(name: name)
        newProjectName = ""
        showingNewProject = false
    }
    
    private func deleteProjects(at offsets: IndexSet) {
        appState.projects.remove(atOffsets: offsets)
    }
}
