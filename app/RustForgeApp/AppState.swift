import Foundation
import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: Tab = .projects
    @Published var selectedProject: Project?
    @Published var selectedFile: ProjectFile?
    @Published var projects: [Project] = []
    @Published var isBuilding = false
    @Published var buildLog: String = ""
    @Published var lastBuildStatus: BuildStatus = .idle
    @Published var settings = Settings()
    
    let runtime = WAMRRuntime.shared
    let fileManager = ProjectFileManager.shared
    
    enum Tab: String, CaseIterable, Identifiable {
        case projects = "Proyectos"
        case editor = "Editor"
        case builder = "UI Builder"
        case terminal = "Terminal"
        case settings = "Ajustes"
        
        var id: String { rawValue }
        
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
    
    enum BuildStatus {
        case idle, running, success, failed
    }
    
    init() { loadProjects() }
    
    func loadProjects() {
        projects = fileManager.loadProjects()
    }
    
    func createProject(name: String) {
        let project = fileManager.createProject(name: name)
        projects.append(project)
        selectedProject = project
        selectedTab = .editor
    }
    
    func openProject(_ project: Project) {
        selectedProject = project
        selectedTab = .editor
    }
}
