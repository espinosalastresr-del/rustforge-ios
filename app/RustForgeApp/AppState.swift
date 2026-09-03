import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    enum Tab: Int, CaseIterable, Hashable {
        case projects = 0
        case editor = 1
        case builder = 2
        case terminal = 3
        case settings = 4

        var title: String {
            switch self {
            case .projects: return "Proyectos"
            case .editor: return "Editor"
            case .builder: return "UI Builder"
            case .terminal: return "Terminal"
            case .settings: return "Ajustes"
            }
        }

        var icon: String {
            switch self {
            case .projects: return "folder.fill"
            case .editor: return "chevron.left.forwardslash.chevron.right"
            case .builder: return "rectangle.3.group.fill"
            case .terminal: return "terminal.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    @Published var projects: [Project] = []
    @Published var selectedProject: Project?
    @Published var selectedFile: ProjectFile?
    @Published var settings: Settings {
        didSet { persistSettings() }
    }
    @Published var selectedTab: Tab = .projects

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
        selectedTab = .editor
    }

    func saveSettings() {
        persistSettings()
    }

    func applyImportedSDK(_ info: SDKManager.SDKInfo) {
        settings.sdkPath = info.path
        settings.sdkVersion = info.version
        if !info.deploymentTarget.isEmpty {
            settings.deploymentTarget = info.deploymentTarget
        }
        persistSettings()
    }

    private func persistSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }
}
