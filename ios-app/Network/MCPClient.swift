import Foundation
import UIKit

extension Notification.Name {
    static let mcpBackgroundUploadFinished = Notification.Name("mcpBackgroundUploadFinished")
    static let mcpBackgroundUploadFailed = Notification.Name("mcpBackgroundUploadFailed")
    
}

@MainActor
final class MCPClient: NSObject {
    private let serverUrl: String
    private let foregroundSession: URLSession
    private let backgroundSession: URLSession
    private let sessionDelegate = MCPURLSessionDelegate()
    
    init(serverUrl: String) {
        self.serverUrl = serverUrl
        // Foreground session for immediate requests (async/await is OK here)
        let fg = URLSessionConfiguration.default
        fg.waitsForConnectivity = true
        fg.allowsCellularAccess = true
        fg.allowsExpensiveNetworkAccess = true
        fg.allowsConstrainedNetworkAccess = true
        self.foregroundSession = URLSession(configuration: fg)

        // Background session for system-managed transfers (no completion handlers)
        let bg = URLSessionConfiguration.background(withIdentifier: "com.yourapp.mcp.upload")
        bg.waitsForConnectivity = true
        bg.isDiscretionary = true
        bg.sessionSendsLaunchEvents = true
        bg.allowsCellularAccess = true
        bg.allowsExpensiveNetworkAccess = true
        bg.allowsConstrainedNetworkAccess = true
        self.backgroundSession = URLSession(configuration: bg, delegate: sessionDelegate, delegateQueue: OperationQueue.main)
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

        let task = backgroundSession.uploadTask(with: request, fromFile: fileURL)
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
        
        let (data, response) = try await foregroundSession.data(for: request)
        
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
            let (_, response) = try await foregroundSession.data(for: request)
            
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
final class MCPURLSessionDelegate: NSObject, URLSessionDelegate, @preconcurrency URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        print(">>> didCompleteWithError invoked for taskId=\(task.taskIdentifier), error=\(String(describing: error))")
        if let httpResponse = task.response as? HTTPURLResponse {
            print(">>> HTTP status code: \(httpResponse.statusCode)")
        } else {
            print(">>> No HTTPURLResponse on task")
        }

        if let error = error {
            print("[MCPClient] Background upload failed: \(error.localizedDescription)")
            NotificationCenter.default.post(
                name: .mcpBackgroundUploadFailed,
                object: nil,
                userInfo: ["error": error.localizedDescription]
            )
        } else {
            print("[MCPClient] Background upload completed: taskId=\(task.taskIdentifier)")
            MCPClient.saveLastSentAt()
            NotificationCenter.default.post(name: .mcpBackgroundUploadFinished, object: nil)
        }
    }

    func urlSessionDidFinishEvents(for session: URLSession) {
        print("[MCPClient] All background events finished")
        DispatchQueue.main.async {
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
               let handler = appDelegate.backgroundCompletionHandler {
                appDelegate.backgroundCompletionHandler = nil
                handler()
            }
        }
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
