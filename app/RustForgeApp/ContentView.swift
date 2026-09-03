import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView(selection: $appState.selectedTab) {
            ProjectsView()
                .tabItem {
                    Label(AppState.Tab.projects.rawValue, systemImage: AppState.Tab.projects.icon)
                }
                .tag(AppState.Tab.projects)
            
            EditorView()
                .tabItem {
                    Label(AppState.Tab.editor.rawValue, systemImage: AppState.Tab.editor.icon)
                }
                .tag(AppState.Tab.editor)
            
            UIBuilderView()
                .tabItem {
                    Label(AppState.Tab.builder.rawValue, systemImage: AppState.Tab.builder.icon)
                }
                .tag(AppState.Tab.builder)
            
            TerminalView()
                .tabItem {
                    Label(AppState.Tab.terminal.rawValue, systemImage: AppState.Tab.terminal.icon)
                }
                .tag(AppState.Tab.terminal)
            
            SettingsView()
                .tabItem {
                    Label(AppState.Tab.settings.rawValue, systemImage: AppState.Tab.settings.icon)
                }
                .tag(AppState.Tab.settings)
        }
        .accentColor(.orange)
    }
}
