import Foundation

class MCPClient {
    private let serverUrl: String
    private let session: URLSession
    
    init(serverUrl: String) {
        self.serverUrl = serverUrl
        self.session = URLSession.shared
    }
    
    func sendHealthData(_ healthData: HealthData) async throws {
        let url = URL(string: "\(serverUrl)/health-data")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let jsonData = try JSONEncoder().encode(healthData)
        request.httpBody = jsonData
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MCPError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw MCPError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
    }
    
    func testConnection() async throws -> Bool {
        let url = URL(string: "\(serverUrl)/health")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0
        
        do {
            let (_, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            
            return 200...299 ~= httpResponse.statusCode
        } catch {
            return false
        }
    }
}

enum MCPError: Error, LocalizedError {
    case invalidResponse
    case serverError(statusCode: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from MCP server"
        case .serverError(let statusCode, let message):
            return "MCP server error (status: \(statusCode)): \(message)"
        }
    }
}