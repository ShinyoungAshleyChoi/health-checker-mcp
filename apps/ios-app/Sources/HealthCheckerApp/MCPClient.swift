
import Foundation

extension Notification.Name {
    static let mcpBackgroundUploadFinished = Notification.Name("mcpBackgroundUploadFinished")
}

@MainActor
final class MCPClient: NSObject {
    private let serverUrl: String
    private let session: URLSession
    private let sessionDelegate = MCPURLSessionDelegate()
    
    init(serverUrl: String) {
        self.serverUrl = serverUrl
        let config = URLSessionConfiguration.background(withIdentifier: "com.yourapp.mcp.upload")
        config.waitsForConnectivity = true
        config.isDiscretionary = true
        config.sessionSendsLaunchEvents = true
        config.allowsCellularAccess = true
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        self.session = URLSession(configuration: config, delegate: sessionDelegate, delegateQueue: nil)
        super.init()
    }

    /// Schedule a background upload to the MCP server. The system handles the transfer even if the app is suspended.
    /// This method enqueues the upload and returns immediately after scheduling.
    func sendHealthDataInBackground(_ healthData: HealthData) throws {
        let url = URL(string: "\(serverUrl)/health-data")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let jsonData = try JSONEncoder().encode(healthData)
        let fileURL = try writeJSONToTempFile(jsonData)

        let task = session.uploadTask(with: request, fromFile: fileURL)
        task.taskDescription = "mcp.healthdata.upload"
        task.resume()
    }

    private func writeJSONToTempFile(_ data: Data, suffix: String = "healthdata") throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(UUID().uuidString + "-\(suffix).json")
        try data.write(to: fileURL, options: [.atomic])
        return fileURL
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
        MCPClient.saveLastSentAt()
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

@MainActor
final class MCPURLSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("[MCPClient] Background upload failed: \(error.localizedDescription)")
        } else {
            print("[MCPClient] Background upload completed: taskId=\(task.taskIdentifier)")
            MCPClient.saveLastSentAt()
            NotificationCenter.default.post(name: .mcpBackgroundUploadFinished, object: nil)
        }
    }

    func urlSessionDidFinishEvents(for session: URLSession) {
        print("[MCPClient] All background events finished")
    }
}


extension MCPClient {
    private static let lastSentAtKey = "mcp.lastSentAt"

    static func loadLastSentAt() -> Date? {
        UserDefaults.standard.object(forKey: lastSentAtKey) as? Date
    }

    @discardableResult
    static func saveLastSentAt(_ date: Date = Date()) -> Date {
        UserDefaults.standard.set(date, forKey: lastSentAtKey)
        return date
    }
}
