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

        // Accept either a full *.sdk folder or a zip/folder that contains SDKSettings.plist
        let candidates = [
            url,
            url.appendingPathComponent("iPhoneOS.sdk"),
            url.appendingPathComponent("SDK"),
        ]

        for candidate in candidates {
            if let info = inspectSDK(at: candidate) {
                return info
            }
            // Search one level deep
            if let children = try? fileManager.contentsOfDirectory(at: candidate, includingPropertiesForKeys: nil) {
                for child in children {
                    if child.lastPathComponent.hasSuffix(".sdk"), let info = inspectSDK(at: child) {
                        return info
                    }
                }
            }
        }
        return nil
    }

    private func inspectSDK(at url: URL) -> SDKInfo? {
        let settingsPlist = url.appendingPathComponent("SDKSettings.plist")
        let versionPlist = url.appendingPathComponent("System/Library/CoreServices/SystemVersion.plist")
        let usrLib = url.appendingPathComponent("usr/lib")

        var version = "unknown"
        var platform = "iPhoneOS"

        if let data = try? Data(contentsOf: settingsPlist),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            if let v = plist["Version"] as? String { version = v }
            if let displayName = plist["DisplayName"] as? String { platform = displayName }
            if let name = plist["CanonicalName"] as? String { platform = name }
        } else if let data = try? Data(contentsOf: versionPlist),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  let v = plist["ProductVersion"] as? String {
            version = v
        }

        let looksValid = fileManager.fileExists(atPath: usrLib.path)
            || fileManager.fileExists(atPath: settingsPlist.path)
            || url.lastPathComponent.hasSuffix(".sdk")

        guard looksValid else { return nil }

        return SDKInfo(
            path: url.path,
            version: version,
            platform: platform,
            deploymentTarget: "17.0",
            architectures: ["arm64"]
        )
    }

    func importSDK(from sourceURL: URL) throws -> SDKInfo {
        // Start security-scoped access if needed (document picker)
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessing { sourceURL.stopAccessingSecurityScopedResource() }
        }

        guard let info = detectSDK(at: sourceURL.path) else {
            throw SDKError.invalidSDK
        }

        let destination = sdkRootURL.appendingPathComponent("current")

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        try fileManager.createDirectory(at: sdkRootURL, withIntermediateDirectories: true)

        // Prefer the detected path (may be nested .sdk inside picked folder)
        let sourcePath = info.path
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

    func clearSDK() throws {
        let current = sdkRootURL.appendingPathComponent("current")
        if fileManager.fileExists(atPath: current.path) {
            try fileManager.removeItem(at: current)
        }
    }

    enum SDKError: Error, LocalizedError {
        case invalidSDK
        case copyFailed

        var errorDescription: String? {
            switch self {
            case .invalidSDK:
                return "La ruta no contiene un SDK de iOS válido (se espera carpeta *.sdk o SDKSettings.plist)"
            case .copyFailed:
                return "No se pudo copiar el SDK al sandbox de la app"
            }
        }
    }
}
