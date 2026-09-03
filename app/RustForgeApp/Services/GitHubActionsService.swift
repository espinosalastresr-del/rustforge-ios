import Foundation
import Compression

/// Cliente para GitHub Actions: disparar workflow, esperar, descargar artefactos.
actor GitHubActionsService {

    struct Config {
        var token: String
        var repository: String
        var workflowFile: String
    }

    enum ServiceError: Error, LocalizedError {
        case missingCredentials
        case invalidURL
        case httpError(Int, String)
        case decodingError
        case timeout
        case noArtifact
        case downloadFailed

        var errorDescription: String? {
            switch self {
            case .missingCredentials: return "GitHub token o repositorio no configurados"
            case .invalidURL: return "URL inválida"
            case .httpError(let code, let body): return "HTTP \(code): \(body)"
            case .decodingError: return "Error decodificando respuesta"
            case .timeout: return "Tiempo de espera agotado"
            case .noArtifact: return "No se encontró artefacto IPA en el run"
            case .downloadFailed: return "Falló la descarga del artefacto"
            }
        }
    }

    func triggerBuild(
        config: Config,
        projectName: String,
        artifactURL: String = "",
        useTemplate: Bool = false
    ) async throws {
        guard !config.token.isEmpty, !config.repository.isEmpty else {
            throw ServiceError.missingCredentials
        }

        let urlString = "https://api.github.com/repos/\(config.repository)/actions/workflows/\(config.workflowFile)/dispatches"
        guard let url = URL(string: urlString) else { throw ServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let body: [String: Any] = [
            "ref": "main",
            "inputs": [
                "project_name": projectName,
                "artifact_url": artifactURL,
                "use_template": useTemplate ? "true" : "false"
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.httpError(-1, "No HTTP response")
        }
        guard (200...299).contains(http.statusCode) else {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            throw ServiceError.httpError(http.statusCode, bodyStr)
        }
    }

    struct WorkflowRun: Decodable, Identifiable {
        let id: Int
        let status: String
        let conclusion: String?
        let html_url: String
        let name: String?
        let created_at: String?
    }

    struct RunsResponse: Decodable {
        let workflow_runs: [WorkflowRun]
    }

    func listRuns(config: Config, perPage: Int = 5) async throws -> [WorkflowRun] {
        let urlString = "https://api.github.com/repos/\(config.repository)/actions/workflows/\(config.workflowFile)/runs?per_page=\(perPage)"
        guard let url = URL(string: urlString) else { throw ServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(config.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            throw ServiceError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1, bodyStr)
        }
        return try JSONDecoder().decode(RunsResponse.self, from: data).workflow_runs
    }

    func waitForCompletion(
        config: Config,
        timeoutSeconds: TimeInterval = 900,
        pollInterval: TimeInterval = 8
    ) async throws -> WorkflowRun {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        try await Task.sleep(nanoseconds: 3_000_000_000)

        while Date() < deadline {
            let runs = try await listRuns(config: config, perPage: 5)
            if let run = runs.first {
                if run.status == "completed" {
                    return run
                }
            }
            try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
        throw ServiceError.timeout
    }

    struct Artifact: Decodable, Identifiable {
        let id: Int
        let name: String
        let size_in_bytes: Int
        let archive_download_url: String
        let expired: Bool
    }

    struct ArtifactsResponse: Decodable {
        let artifacts: [Artifact]
    }

    func listArtifacts(config: Config, runId: Int) async throws -> [Artifact] {
        let urlString = "https://api.github.com/repos/\(config.repository)/actions/runs/\(runId)/artifacts"
        guard let url = URL(string: urlString) else { throw ServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(config.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            throw ServiceError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1, bodyStr)
        }
        return try JSONDecoder().decode(ArtifactsResponse.self, from: data).artifacts
    }

    func downloadIPA(
        config: Config,
        runId: Int,
        projectName: String,
        destinationDirectory: URL
    ) async throws -> URL {
        let artifacts = try await listArtifacts(config: config, runId: runId)
        guard let artifact = artifacts.first(where: { $0.name.contains(projectName) || $0.name.hasPrefix("ios-app") }),
              !artifact.expired else {
            throw ServiceError.noArtifact
        }

        guard let url = URL(string: artifact.archive_download_url) else {
            throw ServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(config.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ServiceError.downloadFailed
        }

        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        let zipURL = destinationDirectory.appendingPathComponent("artifact-\(runId).zip")
        try data.write(to: zipURL)

        let extractDir = destinationDirectory.appendingPathComponent("extract-\(runId)", isDirectory: true)
        try? FileManager.default.removeItem(at: extractDir)
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        try ZipUtil.unzip(zipURL: zipURL, to: extractDir)

        if let ipa = ZipUtil.findFile(suffix: ".ipa", in: extractDir) {
            let dest = destinationDirectory.appendingPathComponent("\(projectName).ipa")
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.copyItem(at: ipa, to: dest)
            return dest
        }

        if let app = ZipUtil.findFile(suffix: ".app", in: extractDir) {
            let dest = destinationDirectory.appendingPathComponent("\(projectName).ipa")
            try ZipUtil.packageAppAsIPA(appURL: app, ipaURL: dest)
            return dest
        }

        throw ServiceError.noArtifact
    }
}

// MARK: - ZIP utilities

enum ZipUtil {
    static func findFile(suffix: String, in directory: URL) -> URL? {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: nil) else { return nil }
        for case let fileURL as URL in enumerator {
            if fileURL.lastPathComponent.hasSuffix(suffix) { return fileURL }
        }
        return nil
    }

    static func unzip(zipURL: URL, to destination: URL) throws {
        let data = try Data(contentsOf: zipURL)
        try unzipData(data, to: destination)
    }

    static func packageAppAsIPA(appURL: URL, ipaURL: URL) throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let payload = temp.appendingPathComponent("Payload", isDirectory: true)
        try FileManager.default.createDirectory(at: payload, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: appURL, to: payload.appendingPathComponent(appURL.lastPathComponent))
        try zipDirectory(temp, to: ipaURL)
        try? FileManager.default.removeItem(at: temp)
    }

    static func zipDirectory(_ directory: URL, to zipURL: URL) throws {
        var files: [(String, Data)] = []
        let fm = FileManager.default
        if let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: [.isDirectoryKey]) {
            for case let fileURL as URL in enumerator {
                var isDir: ObjCBool = false
                fm.fileExists(atPath: fileURL.path, isDirectory: &isDir)
                if isDir.boolValue { continue }
                let relative = fileURL.path.replacingOccurrences(of: directory.path + "/", with: "")
                if let fileData = try? Data(contentsOf: fileURL) {
                    files.append((relative, fileData))
                }
            }
        }
        try buildStoreZip(entries: files).write(to: zipURL)
    }

    private static func unzipData(_ data: Data, to destination: URL) throws {
        var offset = 0
        let bytes = [UInt8](data)
        while offset + 30 < bytes.count {
            let sig = readU32(bytes, offset)
            if sig != 0x04034b50 { break }
            let method = readU16(bytes, offset + 8)
            let compSize = Int(readU32(bytes, offset + 18))
            let uncompSize = Int(readU32(bytes, offset + 22))
            let nameLen = Int(readU16(bytes, offset + 26))
            let extraLen = Int(readU16(bytes, offset + 28))
            let nameStart = offset + 30
            let nameEnd = nameStart + nameLen
            guard nameEnd + extraLen + compSize <= bytes.count else { break }
            let name = String(data: Data(bytes[nameStart..<nameEnd]), encoding: .utf8) ?? "file"
            let dataStart = nameEnd + extraLen
            let dataEnd = dataStart + compSize
            let payload = Data(bytes[dataStart..<dataEnd])

            let outURL = destination.appendingPathComponent(name)
            if name.hasSuffix("/") {
                try FileManager.default.createDirectory(at: outURL, withIntermediateDirectories: true)
            } else {
                try FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                if method == 0 {
                    try payload.write(to: outURL)
                } else if method == 8 {
                    try inflate(payload, expectedSize: max(uncompSize, 1)).write(to: outURL)
                }
            }
            offset = dataEnd
        }
    }

    private static func inflate(_ data: Data, expectedSize: Int) throws -> Data {
        try data.withUnsafeBytes { (src: UnsafeRawBufferPointer) -> Data in
            let dstCapacity = max(expectedSize, data.count * 8 + 64)
            var dst = Data(count: dstCapacity)
            let written = dst.withUnsafeMutableBytes { (dstBuf: UnsafeMutableRawBufferPointer) -> Int in
                guard let srcBase = src.bindMemory(to: UInt8.self).baseAddress,
                      let dstBase = dstBuf.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_decode_buffer(dstBase, dstCapacity, srcBase, data.count, nil, COMPRESSION_ZLIB)
            }
            guard written > 0 else { throw GitHubActionsService.ServiceError.downloadFailed }
            dst.count = written
            return dst
        }
    }

    private static func buildStoreZip(entries: [(String, Data)]) throws -> Data {
        var local = Data()
        var central = Data()
        var offset: UInt32 = 0

        for (name, fileData) in entries {
            let nameData = Data(name.utf8)
            let nameLen = UInt16(nameData.count)
            let size = UInt32(fileData.count)
            let crc = crc32(fileData)

            var localHeader = Data()
            localHeader.append(contentsOf: le32(0x04034b50))
            localHeader.append(contentsOf: le16(20))
            localHeader.append(contentsOf: le16(0))
            localHeader.append(contentsOf: le16(0))
            localHeader.append(contentsOf: le16(0))
            localHeader.append(contentsOf: le16(0))
            localHeader.append(contentsOf: le32(crc))
            localHeader.append(contentsOf: le32(size))
            localHeader.append(contentsOf: le32(size))
            localHeader.append(contentsOf: le16(nameLen))
            localHeader.append(contentsOf: le16(0))
            localHeader.append(nameData)
            localHeader.append(fileData)

            var centralHeader = Data()
            centralHeader.append(contentsOf: le32(0x02014b50))
            centralHeader.append(contentsOf: le16(20))
            centralHeader.append(contentsOf: le16(20))
            centralHeader.append(contentsOf: le16(0))
            centralHeader.append(contentsOf: le16(0))
            centralHeader.append(contentsOf: le16(0))
            centralHeader.append(contentsOf: le16(0))
            centralHeader.append(contentsOf: le32(crc))
            centralHeader.append(contentsOf: le32(size))
            centralHeader.append(contentsOf: le32(size))
            centralHeader.append(contentsOf: le16(nameLen))
            centralHeader.append(contentsOf: le16(0))
            centralHeader.append(contentsOf: le16(0))
            centralHeader.append(contentsOf: le16(0))
            centralHeader.append(contentsOf: le16(0))
            centralHeader.append(contentsOf: le32(0))
            centralHeader.append(contentsOf: le32(offset))
            centralHeader.append(nameData)

            offset += UInt32(localHeader.count)
            local.append(localHeader)
            central.append(centralHeader)
        }

        var end = Data()
        end.append(contentsOf: le32(0x06054b50))
        end.append(contentsOf: le16(0))
        end.append(contentsOf: le16(0))
        end.append(contentsOf: le16(UInt16(entries.count)))
        end.append(contentsOf: le16(UInt16(entries.count)))
        end.append(contentsOf: le32(UInt32(central.count)))
        end.append(contentsOf: le32(UInt32(local.count)))
        end.append(contentsOf: le16(0))

        var result = Data()
        result.append(local)
        result.append(central)
        result.append(end)
        return result
    }

    private static func readU16(_ b: [UInt8], _ i: Int) -> UInt16 {
        UInt16(b[i]) | (UInt16(b[i+1]) << 8)
    }
    private static func readU32(_ b: [UInt8], _ i: Int) -> UInt32 {
        UInt32(b[i]) | (UInt32(b[i+1]) << 8) | (UInt32(b[i+2]) << 16) | (UInt32(b[i+3]) << 24)
    }
    private static func le16(_ v: UInt16) -> [UInt8] {
        [UInt8(v & 0xff), UInt8((v >> 8) & 0xff)]
    }
    private static func le32(_ v: UInt32) -> [UInt8] {
        [UInt8(v & 0xff), UInt8((v >> 8) & 0xff), UInt8((v >> 16) & 0xff), UInt8((v >> 24) & 0xff)]
    }
    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                let mask = (crc & 1) == 0 ? UInt32(0) : UInt32(0xedb88320)
                crc = (crc >> 1) ^ mask
            }
        }
        return ~crc
    }
}
