import Foundation
import ArgumentParser

@main
struct HealthCheckerApp: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "health-checker",
        abstract: "A health checker application with MCP integration",
        version: "1.0.0"
    )

    @Option(name: .shortAndLong, help: "API server URL")
    var apiUrl: String = "http://localhost:8001"

    @Option(name: .shortAndLong, help: "MCP shim URL")
    var mcpUrl: String = "http://localhost:3000"

    @Flag(name: .shortAndLong, help: "Enable verbose output")
    var verbose: Bool = false

    func run() async throws {
        print("🏥 Health Checker iOS App Starting...")

        if verbose {
            print("📡 API URL: \(apiUrl)")
            print("🔗 MCP URL: \(mcpUrl)")
        }

        // Python API 헬스체크
        await checkAPI(url: "\(apiUrl)/health", name: "Python API")

        // MCP Shim 연결 테스트
        await checkAPI(url: mcpUrl, name: "MCP Shim")
    }

    private func checkAPI(url: String, name: String) async {
        print("\n🔍 Checking \(name)...")

        guard let url = URL(string: url) else {
            print("❌ Invalid URL: \(url)")
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                let responseString = String(data: data, encoding: .utf8) ?? "No response body"
                print("✅ \(name): \(responseString)")
            } else {
                print("❌ \(name) Failed: \(response)")
            }
        } catch {
            print("❌ \(name) Error: \(error)")
        }
    }
}
