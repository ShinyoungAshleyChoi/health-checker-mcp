import Foundation
import ArgumentParser

struct HealthCheckerApp: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "health-checker",
        abstract: "iOS Health Data Reader and MCP Client"
    )
    
    @Option(name: .shortAndLong, help: "MCP server URL")
    var serverUrl: String = "http://localhost:8000"
    
    @Flag(name: .shortAndLong, help: "Enable verbose logging")
    var verbose: Bool = false
    
    func run() async throws {
        if verbose {
            print("Starting Health Checker App...")
            print("MCP Server URL: \(serverUrl)")
        }
        
        let healthManager = HealthDataManager()
        let mcpClient = await MCPClient(serverUrl: serverUrl)
        
        do {
            // Request HealthKit authorization
            try await healthManager.requestAuthorization()
            
            // Read health data
            let healthData = try await healthManager.readHealthData()
            
            // Send to MCP server
            try await mcpClient.sendHealthData(healthData)
            
            print("Health data successfully sent to MCP server")
        } catch {
            print("Error: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}
