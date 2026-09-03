import Foundation

struct WASIEnvironment {
    var arguments: [String]
    var environment: [String: String]
    var preopens: [Preopen]
    var stdin: String?
    var captureStdout: Bool
    var captureStderr: Bool
    
    struct Preopen {
        let guestPath: String
        let hostPath: String
    }
    
    static func `default`(arguments: [String] = []) -> WASIEnvironment {
        let vfs = VirtualFileSystem.shared
        
        return WASIEnvironment(
            arguments: arguments,
            environment: [
                "HOME": "/projects",
                "PATH": "/bin",
                "RUSTUP_HOME": "/toolchains",
                "CARGO_HOME": "/cargo",
                "TERM": "xterm-256color"
            ],
            preopens: vfs.wasiPreopens().map {
                Preopen(guestPath: $0.guestPath, hostPath: $0.hostPath)
            },
            stdin: nil,
            captureStdout: true,
            captureStderr: true
        )
    }
}
