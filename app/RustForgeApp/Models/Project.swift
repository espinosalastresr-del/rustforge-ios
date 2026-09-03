import Foundation

struct Project: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var path: String
    var createdAt: Date
    var lastOpenedAt: Date
    var files: [ProjectFile]
    
    init(name: String, path: String) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.createdAt = Date()
        self.lastOpenedAt = Date()
        self.files = []
    }
}

struct ProjectFile: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var path: String
    var relativePath: String
    var isDirectory: Bool
    var children: [ProjectFile]?
    
    init(name: String, path: String, relativePath: String, isDirectory: Bool = false) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.relativePath = relativePath
        self.isDirectory = isDirectory
        self.children = isDirectory ? [] : nil
    }
    
    var isRustFile: Bool { name.hasSuffix(".rs") }
    var isSwiftFile: Bool { name.hasSuffix(".swift") }
    var isTomlFile: Bool { name.hasSuffix(".toml") }
}
