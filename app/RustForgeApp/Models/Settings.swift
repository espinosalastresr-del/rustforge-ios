import Foundation

struct Settings: Codable {
    var maxCompilerWorkers: Int = 1
    var cargoParallelJobs: Int = 1
    var wasmMemoryLimitMB: Int = 512
    var enableAOT: Bool = false
    var cargoCacheSizeMB: Int = 1024
    var offlineMode: Bool = false
    var githubToken: String = ""
    var githubRepo: String = ""
    var githubWorkflowFile: String = "build.yml"
    var sdkPath: String = ""
    var sdkVersion: String = ""
    var deploymentTarget: String = "17.0"
    var fontSize: Double = 14
    var showLineNumbers: Bool = true
    var tabSize: Int = 4
    var defaultUIFramework: UIFramework = .swiftUI
    
    enum UIFramework: String, Codable, CaseIterable {
        case swiftUI = "SwiftUI"
        case uiKit = "UIKit"
    }
}
