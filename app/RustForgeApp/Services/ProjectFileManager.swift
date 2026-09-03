import Foundation

final class ProjectFileManager {
    static let shared = ProjectFileManager()
    private let fileManager = FileManager.default

    private var rootURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RustForge", isDirectory: true)
    }

    private var projectsURL: URL {
        rootURL.appendingPathComponent("projects", isDirectory: true)
    }

    private init() {
        try? fileManager.createDirectory(at: projectsURL, withIntermediateDirectories: true)
    }

    func loadProjects() -> [Project] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: projectsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var projects: [Project] = []
        for url in contents {
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { continue }
            var project = Project(name: url.lastPathComponent, path: url.path)
            project.files = loadFiles(in: url, relativeTo: url)
            projects.append(project)
        }
        return projects.sorted { $0.lastOpenedAt > $1.lastOpenedAt }
    }

    /// Crea un proyecto hybrid Rust staticlib + SwiftUI listo para CI / LiveContainer.
    func createProject(name: String) -> Project {
        let safeName = name.replacingOccurrences(of: " ", with: "-").lowercased()
        let crateName = safeName.replacingOccurrences(of: "-", with: "_")
        let projectURL = projectsURL.appendingPathComponent(safeName, isDirectory: true)
        try? fileManager.createDirectory(at: projectURL, withIntermediateDirectories: true)

        let cargoToml = """
        [package]
        name = "\(crateName)"
        version = "0.1.0"
        edition = "2021"

        [lib]
        name = "\(crateName)"
        crate-type = ["staticlib"]

        [dependencies]
        """
        try? cargoToml.write(to: projectURL.appendingPathComponent("Cargo.toml"), atomically: true, encoding: .utf8)

        let srcURL = projectURL.appendingPathComponent("src", isDirectory: true)
        try? fileManager.createDirectory(at: srcURL, withIntermediateDirectories: true)

        let libRs = """
        #[no_mangle]
        pub extern "C" fn rustforge_add(a: i32, b: i32) -> i32 {
            a + b
        }

        #[no_mangle]
        pub extern "C" fn rustforge_version() -> i32 {
            1
        }
        """
        try? libRs.write(to: srcURL.appendingPathComponent("lib.rs"), atomically: true, encoding: .utf8)

        let iosURL = projectURL.appendingPathComponent("ios", isDirectory: true)
        try? fileManager.createDirectory(at: iosURL, withIntermediateDirectories: true)

        let contentView = """
        import SwiftUI

        struct ContentView: View {
            var body: some View {
                VStack(spacing: 16) {
                    Text("\(name)")
                        .font(.title.bold())
                    Text("Rust + SwiftUI hybrid")
                        .foregroundStyle(.secondary)
                    Text("2 + 3 = \\(rustforge_add(2, 3))")
                        .font(.title2.monospaced())
                }
                .padding()
            }
        }
        """
        try? contentView.write(to: iosURL.appendingPathComponent("ContentView.swift"), atomically: true, encoding: .utf8)

        let appSwift = """
        import SwiftUI

        @main
        struct \(crateName.prefix(1).uppercased())\(crateName.dropFirst())App: App {
            var body: some Scene {
                WindowGroup {
                    ContentView()
                }
            }
        }
        """
        // Simpler @main name
        let appSimple = """
        import SwiftUI

        @main
        struct AppMain: App {
            var body: some Scene {
                WindowGroup {
                    ContentView()
                }
            }
        }
        """
        try? appSimple.write(to: iosURL.appendingPathComponent("App.swift"), atomically: true, encoding: .utf8)

        let bridging = """
        #ifndef bridging_h
        #define bridging_h
        #include <stdint.h>
        #ifdef __cplusplus
        extern "C" {
        #endif
        int32_t rustforge_add(int32_t a, int32_t b);
        int32_t rustforge_version(void);
        #ifdef __cplusplus
        }
        #endif
        #endif
        """
        try? bridging.write(to: iosURL.appendingPathComponent("bridging.h"), atomically: true, encoding: .utf8)

        var project = Project(name: name, path: projectURL.path)
        project.files = loadFiles(in: projectURL, relativeTo: projectURL)
        return project
    }

    private func loadFiles(in directory: URL, relativeTo root: URL) -> [ProjectFile] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var files: [ProjectFile] = []
        for url in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            var isDir: ObjCBool = false
            fileManager.fileExists(atPath: url.path, isDirectory: &isDir)
            let relative = url.path.replacingOccurrences(of: root.path + "/", with: "")
            var file = ProjectFile(
                name: url.lastPathComponent,
                path: url.path,
                relativePath: relative,
                isDirectory: isDir.boolValue
            )
            if isDir.boolValue {
                file.children = loadFiles(in: url, relativeTo: root)
            }
            files.append(file)
        }
        return files
    }

    func readFile(at path: String) -> String? {
        try? String(contentsOfFile: path, encoding: .utf8)
    }

    func writeFile(content: String, at path: String) -> Bool {
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    /// Escribe código generado por el UI Builder en ios/ContentView.swift del proyecto.
    func writeGeneratedUI(code: String, into project: Project) -> Bool {
        let url = URL(fileURLWithPath: project.path)
            .appendingPathComponent("ios", isDirectory: true)
            .appendingPathComponent("ContentView.swift")
        try? fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        return writeFile(content: code, at: url.path)
    }
}
