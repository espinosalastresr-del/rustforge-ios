import Foundation

struct ProcessResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
    let duration: TimeInterval
    
    var success: Bool { exitCode == 0 }
    
    var combinedOutput: String {
        var parts: [String] = []
        if !stdout.isEmpty { parts.append(stdout) }
        if !stderr.isEmpty { parts.append(stderr) }
        return parts.joined(separator: "\n")
    }
}

extension ProcessResult {
    static func failure(_ message: String) -> ProcessResult {
        ProcessResult(exitCode: 1, stdout: "", stderr: message, duration: 0)
    }
}
