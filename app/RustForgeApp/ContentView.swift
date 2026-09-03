import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            ProjectsView()
                .tabItem {
                    Label(AppState.Tab.projects.title, systemImage: AppState.Tab.projects.icon)
                }
                .tag(AppState.Tab.projects)

            EditorView()
                .tabItem {
                    Label(AppState.Tab.editor.title, systemImage: AppState.Tab.editor.icon)
                }
                .tag(AppState.Tab.editor)

            UIBuilderView()
                .tabItem {
                    Label(AppState.Tab.builder.title, systemImage: AppState.Tab.builder.icon)
                }
                .tag(AppState.Tab.builder)

            TerminalView()
                .tabItem {
                    Label(AppState.Tab.terminal.title, systemImage: AppState.Tab.terminal.icon)
                }
                .tag(AppState.Tab.terminal)

            SettingsView()
                .tabItem {
                    Label(AppState.Tab.settings.title, systemImage: AppState.Tab.settings.icon)
                }
                .tag(AppState.Tab.settings)
        }
        .tint(.orange)
    }
}
