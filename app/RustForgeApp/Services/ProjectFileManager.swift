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
    
    func createProject(name: String) -> Project {
        let safeName = name.replacingOccurrences(of: " ", with: "-").lowercased()
        let crateName = safeName.replacingOccurrences(of: "-", with: "_")
        let projectURL = projectsURL.appendingPathComponent(safeName, isDirectory: true)
        try? fileManager.createDirectory(at: projectURL, withIntermediateDirectories: true)
        
        let cargoToml = """
        [package]
        name = "\(safeName)"
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
        use std::ffi::CString;
        use std::os::raw::c_char;
        
        #[no_mangle]
        pub extern "C" fn rust_greeting() -> *mut c_char {
            CString::new("Hello from Rust!").unwrap().into_raw()
        }
        
        #[no_mangle]
        pub extern "C" fn rust_add(a: i32, b: i32) -> i32 { a + b }
        
        #[no_mangle]
        pub unsafe extern "C" fn rust_string_free(ptr: *mut c_char) {
            if !ptr.is_null() { let _ = CString::from_raw(ptr); }
        }
        """
        try? libRs.write(to: srcURL.appendingPathComponent("lib.rs"), atomically: true, encoding: .utf8)
        
        let swiftURL = projectURL.appendingPathComponent("iOS", isDirectory: true)
        try? fileManager.createDirectory(at: swiftURL, withIntermediateDirectories: true)
        
        let contentView = """
        import SwiftUI
        
        struct ContentView: View {
            var body: some View {
                VStack(spacing: 20) {
                    Text("Hello from SwiftUI + Rust").font(.title)
                    Text("Edit this UI with the Drag & Drop builder").foregroundStyle(.secondary)
                }.padding()
            }
        }
        """
        try? contentView.write(to: swiftURL.appendingPathComponent("ContentView.swift"), atomically: true, encoding: .utf8)
        
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
}
