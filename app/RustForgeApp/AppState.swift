import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var projects: [Project] = []
    @Published var selectedProject: Project?
    @Published var selectedFile: ProjectFile?
    @Published var settings: Settings {
        didSet { persistSettings() }
    }
    @Published var selectedTab: Int = 0

    private let settingsKey = "rustforge.settings"

    init() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(Settings.self, from: data) {
            settings = decoded
        } else {
            settings = Settings()
        }
        refreshProjects()
    }

    func refreshProjects() {
        projects = ProjectFileManager.shared.loadProjects()
        if let selected = selectedProject,
           let updated = projects.first(where: { $0.path == selected.path }) {
            selectedProject = updated
        }
    }

    func createProject(name: String) {
        let project = ProjectFileManager.shared.createProject(name: name)
        refreshProjects()
        openProject(project)
    }

    func openProject(_ project: Project) {
        selectedProject = project
        selectedFile = nil
        selectedTab = 1 // Editor
    }

    func saveSettings() {
        persistSettings()
    }

    private func persistSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }
}
