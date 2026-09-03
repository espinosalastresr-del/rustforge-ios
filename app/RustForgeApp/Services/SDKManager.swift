import Foundation

/// Gestiona la importación y detección del SDK de Apple.
final class SDKManager {
    static let shared = SDKManager()
    
    private let vfs = VirtualFileSystem.shared
    private let fileManager = FileManager.default
    
    private init() {}
    
    var sdkRootURL: URL {
        vfs.resolve("sdk")
    }
    
    struct SDKInfo: Equatable {
        var path: String
        var version: String
        var platform: String
        var deploymentTarget: String
        var architectures: [String]
    }
    
    func detectSDK(at path: String) -> SDKInfo? {
        let url = URL(fileURLWithPath: path)
        let settingsPlist = url.appendingPathComponent("SDKSettings.plist")
        let versionPlist = url.appendingPathComponent("System/Library/CoreServices/SystemVersion.plist")
        
        var version = "unknown"
        var platform = "iPhoneOS"
        
        if let data = try? Data(contentsOf: settingsPlist),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            if let v = plist["Version"] as? String { version = v }
            if let displayName = plist["DisplayName"] as? String { platform = displayName }
        } else if let data = try? Data(contentsOf: versionPlist),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  let v = plist["ProductVersion"] as? String {
            version = v
        }
        
        let usrLib = url.appendingPathComponent("usr/lib")
        guard fileManager.fileExists(atPath: usrLib.path) || fileManager.fileExists(atPath: settingsPlist.path) else {
            return nil
        }
        
        return SDKInfo(
            path: path,
            version: version,
            platform: platform,
            deploymentTarget: "17.0",
            architectures: ["arm64"]
        )
    }
    
    func importSDK(from sourcePath: String) throws -> SDKInfo {
        guard let info = detectSDK(at: sourcePath) else {
            throw SDKError.invalidSDK
        }
        
        let destination = sdkRootURL.appendingPathComponent("current")
        
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        
        try fileManager.createDirectory(at: sdkRootURL, withIntermediateDirectories: true)
        try fileManager.copyItem(atPath: sourcePath, toPath: destination.path)
        
        var imported = info
        imported.path = destination.path
        return imported
    }
    
    func currentSDK() -> SDKInfo? {
        let current = sdkRootURL.appendingPathComponent("current")
        guard fileManager.fileExists(atPath: current.path) else { return nil }
        return detectSDK(at: current.path)
    }
    
    enum SDKError: Error, LocalizedError {
        case invalidSDK
        case copyFailed
        
        var errorDescription: String? {
            switch self {
            case .invalidSDK: return "La ruta no contiene un SDK de iOS válido"
            case .copyFailed: return "No se pudo copiar el SDK al sandbox"
            }
        }
    }
}
