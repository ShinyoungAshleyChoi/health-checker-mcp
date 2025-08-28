import SwiftUI
import Combine

struct HealthSyncView: View {
    @StateObject private var backgroundTaskManager = BackgroundTaskManager.shared
    @StateObject private var healthDataManager = HealthDataManager()

    private let mcpClient = MCPClient(serverUrl: "http://192.168.45.185:8000")

    @State private var lastManualSentAt: Date? = MCPClient.loadLastSentAt()
    @State private var isSendingManually = false
    @State private var manualSendStatus: String?
    @State private var hasHealthPermission = false
    @State private var isRequestingPermission = false
    @State private var serverConnectionStatus: String = "연결 확인 중..."

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // 시뮬레이터 알림
                #if targetEnvironment(simulator)
                simulatorNoticeSection
                #endif

                // 서버 연결 상태
                serverStatusSection

                // 헬스킷 권한 상태
                healthPermissionSection

                // 백그라운드 동기화 설정
                backgroundSyncSection

                // 수동 전송 섹션
                manualSendSection

                Spacer() // 남은 공간 채우기
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("건강 데이터 동기화")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            await checkServerConnection()
            await requestHealthPermissionIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            backgroundTaskManager.handleAppDidEnterBackground()
        }
        .onReceive(NotificationCenter.default.publisher(for: .mcpBackgroundUploadFinished)) { _ in
            self.lastManualSentAt = MCPClient.loadLastSentAt()
        }
        .onReceive(NotificationCenter.default.publisher(for: .mcpBackgroundUploadFailed)) { notification in
            if let error = notification.userInfo?["error"] as? String {
                self.manualSendStatus = "전송 실패: \(error)"
            }
        }
    }

    // MARK: - Simulator Notice Section
    #if targetEnvironment(simulator)
    private var simulatorNoticeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("시뮬레이터 모드", systemImage: "iphone")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.orange)

            Text("모의 건강 데이터를 사용합니다.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.systemYellow).opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemYellow), lineWidth: 1)
        )
    }
    #endif

    // MARK: - Server Status Section
    private var serverStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("서버 연결 상태", systemImage: "network")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack {
                Circle()
                    .fill(serverConnectionColor)
                    .frame(width: 6, height: 6)
                Text(serverConnectionStatus)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("확인") {
                    Task { await checkServerConnection() }
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private var serverConnectionColor: Color {
        if serverConnectionStatus.contains("연결됨") {
            return .green
        } else if serverConnectionStatus.contains("실패") {
            return .red
        } else {
            return .orange
        }
    }

    // MARK: - Health Permission Section
    private var healthPermissionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("HealthKit 권한", systemImage: "heart.fill")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack {
                Circle()
                    .fill(hasHealthPermission ? .green : .red)
                    .frame(width: 6, height: 6)
                Text(hasHealthPermission ? "권한 허용됨" : "권한 필요")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()

                if !hasHealthPermission {
                    Button("권한 요청") {
                        Task { await requestHealthPermission() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .disabled(isRequestingPermission)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    // MARK: - Background Sync Section
    private var backgroundSyncSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("백그라운드 자동 동기화", systemImage: "arrow.clockwise")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                NavigationLink(destination: BackgroundSyncHelpView()) {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
                Toggle("", isOn: $backgroundTaskManager.isBackgroundSyncEnabled)
                    .disabled(backgroundTaskManager.isSimulator)
                    .scaleEffect(0.8)
            }

            if backgroundTaskManager.isBackgroundSyncEnabled {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("상태:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(backgroundTaskManager.backgroundSyncStatus)
                            .font(.caption2)
                            .foregroundColor(backgroundTaskManager.isSimulator ? .orange : .primary)
                    }

                    if let lastSync = backgroundTaskManager.lastBackgroundSyncAt {
                        HStack {
                            Text("마지막:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(formatted(lastSync))
                                .font(.caption2)
                                .monospaced()
                        }
                    }

                    Button("테스트") {
                        Task {
                            await backgroundTaskManager.triggerBackgroundSyncTest()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }

            // 시뮬레이터 경고
            if backgroundTaskManager.isSimulator {
                Text("⚠️ 시뮬레이터에서는 실제 백그라운드 작업이 제한됩니다.")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    // MARK: - Manual Send Section
    private var manualSendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("수동 전송", systemImage: "paperplane.fill")
                .font(.subheadline)
                .fontWeight(.medium)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("마지막:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(formatted(lastManualSentAt))
                        .font(.caption2)
                        .monospaced()
                }

                if let status = manualSendStatus {
                    Text(status)
                        .font(.caption2)
                        .foregroundColor(status.contains("실패") ? .red : .green)
                }
            }

            Button(action: {
                Task { await sendHealthDataNow() }
            }) {
                HStack {
                    if isSendingManually {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.caption)
                    }
                    Text(isSendingManually ? "전송 중..." : "지금 전송")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isSendingManually || !hasHealthPermission)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    // MARK: - Helper Methods
    private func formatted(_ date: Date?) -> String {
        guard let date else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func checkServerConnection() async {
        serverConnectionStatus = "연결 확인 중..."
        do {
            let isConnected = try await mcpClient.testConnection()
            serverConnectionStatus = isConnected ? "서버에 연결됨" : "서버 연결 실패"
        } catch {
            serverConnectionStatus = "서버 연결 실패: \(error.localizedDescription)"
        }
    }

    private func requestHealthPermissionIfNeeded() async {
        #if targetEnvironment(simulator)
        // 시뮬레이터에서는 자동으로 권한 허용
        await MainActor.run {
            hasHealthPermission = true
        }
        return
        #else
        do {
            try await healthDataManager.requestAuthorization()
            await MainActor.run {
                hasHealthPermission = true
            }
        } catch {
            print("헬스킷 권한 확인 실패: \(error)")
        }
        #endif
    }

    private func requestHealthPermission() async {
        isRequestingPermission = true
        defer { isRequestingPermission = false }

        #if targetEnvironment(simulator)
        // 시뮬레이터에서는 자동으로 권한 허용
        hasHealthPermission = true
        return
        #else
        do {
            try await healthDataManager.requestAuthorization()
            hasHealthPermission = true
        } catch {
            print("헬스킷 권한 요청 실패: \(error)")
        }
        #endif
    }

    @MainActor
    private func sendHealthDataNow() async {
        guard hasHealthPermission else {
            manualSendStatus = "HealthKit 권한이 필요합니다"
            return
        }

        isSendingManually = true
        manualSendStatus = "헬스 데이터 읽는 중..."

        do {
            let healthData = try await healthDataManager.readHealthData()
            manualSendStatus = "서버로 전송 중..."

            try await mcpClient.sendHealthData(healthData)

            lastManualSentAt = MCPClient.loadLastSentAt()
            manualSendStatus = "전송 완료"

        } catch {
            manualSendStatus = "전송 실패: \(error.localizedDescription)"
        }

        isSendingManually = false
    }
}

// MARK: - Preview
struct HealthSyncView_Previews: PreviewProvider {
    static var previews: some View {
        HealthSyncView()
    }
}
