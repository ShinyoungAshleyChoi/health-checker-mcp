import SwiftUI

struct SendNowView: View {
    // ⚠️ 네 서버 주소로 바꿔줘야 해
    private let client = MCPClient(serverUrl: "https://your-mcp-server.example.com")
    
    @State private var lastSentAt: Date? = MCPClient.loadLastSentAt()
    @State private var isSending = false
    @State private var statusText: String?

    var body: some View {
        VStack(spacing: 16) {
            Group {
                Text("마지막 전송 시간")
                    .font(.headline)
                Text(formatted(lastSentAt))
                    .font(.title3)
                    .monospacedDigit()
            }

            if let statusText {
                Text(statusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await sendNow() }
            } label: {
                if isSending {
                    ProgressView().padding(.vertical, 8)
                } else {
                    Text("지금 전송")
                        .font(.body.weight(.semibold))
                        .padding(.vertical, 8)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSending)

            // 옵션: 서버 연결 확인용
            Button("서버 연결 테스트") {
                Task {
                    let ok = (try? await client.testConnection()) ?? false
                    statusText = ok ? "서버 연결 OK" : "서버 연결 실패"
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
        .onReceive(NotificationCenter.default.publisher(for: .mcpBackgroundUploadFinished)) { _ in
            self.lastSentAt = MCPClient.loadLastSentAt()
            self.statusText = "백그라운드 업로드 완료"
        }
    }

    private func sendNow() async {
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
//extension HealthData {
//    static func sample() -> HealthData {
//        return HealthData(
//
//        ) // HealthData 모델 초기화에 맞게 수정
//    }
//}
