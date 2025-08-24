import SwiftUI
import Combine

struct SendNowView: View {
    private let client = MCPClient(serverUrl: "https://localhost:8000")
    
    @State private var lastSentAt: Date? = MCPClient.loadLastSentAt()
    @State private var isSending = false
    @State private var statusText: String?

    var body: some View {
        VStack(spacing: 16) {
            Group {
                Text("마지막 전송 시간")
                    .font(.headline)
                Text(formatted(lastSentAt))
                    .font(.system(size: 17, weight: .regular, design: .monospaced))
            }

            if let statusText {
                Text(statusText)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Button {
                Task { @MainActor [client] in
                    await sendNow(client: client)
                }
            } label: {
                if isSending {
                    ProgressView().padding(.vertical, 8)
                } else {
                    Text("지금 전송")
                        .font(.body)
                        .fontWeight(.semibold)
                        .padding(.vertical, 8)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isSending)
        }
        .padding(24)
        .onReceive(NotificationCenter.default.publisher(for: .mcpBackgroundUploadFinished)) { _ in
            self.lastSentAt = MCPClient.loadLastSentAt()
            self.statusText = "백그라운드 업로드 완료"
        }
    }

    @MainActor
    private func sendNow(client: MCPClient) async {
        isSending = true
        defer { isSending = false }
        statusText = "전송 중…"

        do {
            // ⚠️ 실제 헬스 데이터 가져오는 코드로 교체 필요
            let healthData = HealthData.sample()

            try await client.sendHealthData(healthData)
            self.lastSentAt = MCPClient.loadLastSentAt()
            statusText = "전송 완료"
        } catch {
            statusText = "전송 실패: \(error.localizedDescription)"
        }
    }

    private func formatted(_ date: Date?) -> String {
        guard let date else { return "—" }
        let df = DateFormatter()
        df.locale = .current
        df.dateStyle = .medium
        df.timeStyle = .medium
        return df.string(from: date)
    }
}

// MARK: - 샘플 데이터 (HealthData 정의와 맞게 수정/삭제)
extension HealthData {
    static func sample() -> HealthData {
        return HealthData(
          stepCount: 123,
          heartRate: 123,
          activeEnergyBurned: 123,
          distanceWalkingRunning: 123,
          bodyMass: 60,
          height: 160,
          mindfulMinutes: 1,
          sleepSegments: [],
          totalSleepMinutes: 12,
          timestamp: Date()
        ) // HealthData 모델 초기화에 맞게 수정
    }
}
