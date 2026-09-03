import Foundation

/// Cliente mínimo para interactuar con GitHub Actions.
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
        
        var errorDescription: String? {
            switch self {
            case .missingCredentials: return "GitHub token o repositorio no configurados"
            case .invalidURL: return "URL inválida"
            case .httpError(let code, let body): return "HTTP \(code): \(body)"
            case .decodingError: return "Error decodificando respuesta"
            case .timeout: return "Tiempo de espera agotado"
            }
        }
    }
    
    func triggerBuild(
        config: Config,
        projectName: String,
        artifactURL: String
    ) async throws -> String {
        guard !config.token.isEmpty, !config.repository.isEmpty else {
            throw ServiceError.missingCredentials
        }
        
        let urlString = "https://api.github.com/repos/\(config.repository)/actions/workflows/\(config.workflowFile)/dispatches"
        guard let url = URL(string: urlString) else {
            throw ServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        
        let body: [String: Any] = [
            "ref": "main",
            "inputs": [
                "project_name": projectName,
                "artifact_url": artifactURL
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
        
        return "dispatched"
    }
    
    struct WorkflowRun: Decodable {
        let id: Int
        let status: String
        let conclusion: String?
        let html_url: String
    }
    
    struct RunsResponse: Decodable {
        let workflow_runs: [WorkflowRun]
    }
    
    func latestRun(config: Config) async throws -> WorkflowRun? {
        let urlString = "https://api.github.com/repos/\(config.repository)/actions/runs?per_page=1"
        guard let url = URL(string: urlString) else {
            throw ServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(config.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            throw ServiceError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1, bodyStr)
        }
        
        let decoded = try JSONDecoder().decode(RunsResponse.self, from: data)
        return decoded.workflow_runs.first
    }
    
    func waitForCompletion(
        config: Config,
        timeoutSeconds: TimeInterval = 600,
        pollInterval: TimeInterval = 10
    ) async throws -> WorkflowRun {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        
        while Date() < deadline {
            if let run = try await latestRun(config: config) {
                if run.status == "completed" {
                    return run
                }
            }
            try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
        
        throw ServiceError.timeout
    }
}
