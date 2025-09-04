import Foundation
import BackgroundTasks
import UIKit

@MainActor
final class BackgroundTaskManager: ObservableObject {
    static let shared = BackgroundTaskManager()

    private let backgroundTaskIdentifier = "sychoi.ios-app.healthdata-sync"
    private let healthDataManager = HealthDataManager()
    private let mcpClient = MCPClient(serverUrl: "http://192.168.45.185:8000")

    @Published var isBackgroundSyncEnabled = UserDefaults.standard.bool(forKey: "backgroundSyncEnabled") {
        didSet {
            UserDefaults.standard.set(isBackgroundSyncEnabled, forKey: "backgroundSyncEnabled")
            if isBackgroundSyncEnabled {
                scheduleBackgroundSync()
                startSimulatorPeriodicSync()
            } else {
                cancelBackgroundSync()
            }
        }
    }

    @Published var lastBackgroundSyncAt: Date? = UserDefaults.standard.object(forKey: "lastBackgroundSyncAt") as? Date
    @Published var backgroundSyncStatus: String = "백그라운드 동기화 준비됨"
    @Published var isSimulator: Bool = false

    private init() {
        // 시뮬레이터 감지
        #if targetEnvironment(simulator)
        isSimulator = true
        backgroundSyncStatus = "시뮬레이터에서는 백그라운드 작업이 제한됩니다"
        #endif

        registerBackgroundTasks()
    }

    private func registerBackgroundTasks() {
        let success = BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            print("[BackgroundTask] 백그라운드 작업 실행: \(task.identifier)")
            Task { @MainActor in
                await self.handleBackgroundSync(task: task as! BGAppRefreshTask)
            }
        }

        if success {
            print("[BackgroundTask] 백그라운드 작업 등록 성공: \(backgroundTaskIdentifier)")
        } else {
            print("[BackgroundTask] 백그라운드 작업 등록 실패: \(backgroundTaskIdentifier)")
        }
    }

    func scheduleBackgroundSync() {
        // 시뮬레이터에서는 백그라운드 작업 예약을 시뮬레이션
        #if targetEnvironment(simulator)
        backgroundSyncStatus = "시뮬레이터: 백그라운드 동기화 시뮬레이션됨"
        print("[BackgroundTask] 시뮬레이터에서는 백그라운드 작업이 시뮬레이션됩니다.")
        return
        #endif

        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15분 후

        do {
            try BGTaskScheduler.shared.submit(request)
            backgroundSyncStatus = "백그라운드 동기화 예약됨"
            print("[BackgroundTask] 백그라운드 동기화 작업이 예약되었습니다.")
        } catch {
            let errorCode = (error as NSError).code
            let errorDomain = (error as NSError).domain

            print("[BackgroundTask] 백그라운드 작업 예약 실패: Domain=\(errorDomain), Code=\(errorCode), Error=\(error)")

            switch errorCode {
            case 1: // BGTaskSchedulerErrorUnavailable
                backgroundSyncStatus = "백그라운드 앱 새로고침이 비활성화됨"
            case 2: // BGTaskSchedulerErrorTooManyPendingTaskRequests
                backgroundSyncStatus = "너무 많은 대기 중인 작업"
            case 3: // BGTaskSchedulerErrorNotPermitted
                backgroundSyncStatus = "백그라운드 작업 권한 없음"
            default:
                backgroundSyncStatus = "백그라운드 동기화 예약 실패: \(error.localizedDescription)"
            }
        }
    }

    func cancelBackgroundSync() {
        #if targetEnvironment(simulator)
        backgroundSyncStatus = "시뮬레이터: 백그라운드 동기화 취소됨"
        print("[BackgroundTask] 시뮬레이터에서 백그라운드 작업 취소 시뮬레이션.")
        return
        #endif

        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundTaskIdentifier)
        backgroundSyncStatus = "백그라운드 동기화 취소됨"
        print("[BackgroundTask] 백그라운드 동기화 작업이 취소되었습니다.")
    }

    private func handleBackgroundSync(task: BGAppRefreshTask) async {
        print("[BackgroundTask] 백그라운드 동기화 작업 시작")
        backgroundSyncStatus = "백그라운드 동기화 중..."

        // 다음 작업 예약
        if isBackgroundSyncEnabled {
            scheduleBackgroundSync()
        }

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        do {
            // 첫 백그라운드 전송인지 확인
            let isFirstBackgroundSync = UserDefaults.standard.object(forKey: "lastBackgroundSyncAt") == nil

            if isFirstBackgroundSync {
                // 첫 백그라운드 전송시 전체 데이터
                print("[BackgroundTask] 첫 백그라운드 동기화 - 전체 데이터 전송")
                let healthData = try await healthDataManager.readHealthData()
                try mcpClient.sendHealthDataInBackground(healthData)
            } else {
                // 이후에는 증분 데이터를 개별 전송
                let lastBackgroundSync = lastBackgroundSyncAt ?? Date.distantPast
                print("[BackgroundTask] 마지막 백그라운드 동기화: \(lastBackgroundSync)")

                try await healthDataManager.readAndSendIncrementalHealthData(since: lastBackgroundSync) { healthData in
                    try mcpClient.sendHealthDataInBackground(healthData)
                }
            }

            print("[BackgroundTask] 데이터 전송 완료")

            // 성공 시 상태 업데이트
            lastBackgroundSyncAt = Date()
            UserDefaults.standard.set(lastBackgroundSyncAt, forKey: "lastBackgroundSyncAt")
            backgroundSyncStatus = isFirstBackgroundSync ? "첫 전체 동기화 완료" : "백그라운드 동기화 완료"

            task.setTaskCompleted(success: true)
            print("[BackgroundTask] 백그라운드 동기화 성공")

        } catch {
            backgroundSyncStatus = "백그라운드 동기화 실패: \(error.localizedDescription)"
            task.setTaskCompleted(success: false)
            print("[BackgroundTask] 백그라운드 동기화 실패: \(error)")
        }
    }

    // 앱이 백그라운드로 이동할 때 호출
    func handleAppDidEnterBackground() {
        #if targetEnvironment(simulator)
        print("[BackgroundTask] 시뮬레이터에서 백그라운드 진입 - 실제 스케줄링 생략")
        return
        #endif

        if isBackgroundSyncEnabled {
            print("[BackgroundTask] 앱이 백그라운드로 진입 - 백그라운드 작업 스케줄링 시작")
            scheduleBackgroundSync()
        }
    }

    // 수동으로 백그라운드 동기화 테스트
    func triggerBackgroundSyncTest() async {
        guard isBackgroundSyncEnabled else { return }

        #if targetEnvironment(simulator)
        backgroundSyncStatus = "시뮬레이터: 테스트 동기화 중..."

        // 시뮬레이터에서는 직접 동기화 실행
        do {
            // 첫 백그라운드 테스트인지 확인
            let isFirstBackgroundSync = UserDefaults.standard.object(forKey: "lastBackgroundSyncAt") == nil

            if isFirstBackgroundSync {
                // 첫 백그라운드 테스트시 전체 데이터
                print("[BackgroundTask] 시뮬레이터: 첫 테스트 - 전체 데이터")
                let healthData = try await healthDataManager.readHealthData()
                try mcpClient.sendHealthDataInBackground(healthData)
            } else {
                // 이후에는 증분 데이터를 개별 전송
                let lastBackgroundSync = lastBackgroundSyncAt ?? Date.distantPast
                try await healthDataManager.readAndSendIncrementalHealthData(since: lastBackgroundSync) { healthData in
                    try mcpClient.sendHealthDataInBackground(healthData)
                }
            }

            lastBackgroundSyncAt = Date()
            UserDefaults.standard.set(lastBackgroundSyncAt, forKey: "lastBackgroundSyncAt")
            backgroundSyncStatus = isFirstBackgroundSync ? "시뮬레이터: 첫 전체 테스트 완료" : "시뮬레이터: 테스트 동기화 완료"

        } catch {
            backgroundSyncStatus = "시뮬레이터: 테스트 동기화 실패 - \(error.localizedDescription)"
        }
        return
        #endif

        backgroundSyncStatus = "테스트 동기화 중..."

        do {
            // 첫 백그라운드 테스트인지 확인
            let isFirstBackgroundSync = UserDefaults.standard.object(forKey: "lastBackgroundSyncAt") == nil

            if isFirstBackgroundSync {
                // 첫 백그라운드 테스트시 전체 데이터
                print("[BackgroundTask] 첫 테스트 - 전체 데이터 전송")
                let healthData = try await healthDataManager.readHealthData()
                try mcpClient.sendHealthDataInBackground(healthData)
            } else {
                // 이후에는 증분 데이터를 개별 전송
                let lastBackgroundSync = lastBackgroundSyncAt ?? Date.distantPast
                try await healthDataManager.readAndSendIncrementalHealthData(since: lastBackgroundSync) { healthData in
                    try mcpClient.sendHealthDataInBackground(healthData)
                }
            }

            lastBackgroundSyncAt = Date()
            UserDefaults.standard.set(lastBackgroundSyncAt, forKey: "lastBackgroundSyncAt")
            backgroundSyncStatus = isFirstBackgroundSync ? "첫 전체 테스트 완료" : "테스트 동기화 완료"

        } catch {
            backgroundSyncStatus = "테스트 동기화 실패: \(error.localizedDescription)"
        }
    }

    // 시뮬레이터용 주기적 동기화 (테스트용)
    private func startSimulatorPeriodicSync() {
        #if targetEnvironment(simulator)
        guard isBackgroundSyncEnabled else { return }

        Task {
            while isBackgroundSyncEnabled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30초 대기
                await triggerBackgroundSyncTest()
            }
        }
        #endif
    }

    // 헬스데이터 변경 시 자동 백그라운드 동기화 트리거
    func triggerHealthDataSync() async {
        guard isBackgroundSyncEnabled else {
            print("[BackgroundTask] 백그라운드 동기화가 비활성화됨")
            return
        }

        print("[BackgroundTask] 헬스데이터 변경 감지로 인한 자동 동기화 트리거")
        backgroundSyncStatus = "헬스데이터 변경 감지 - 동기화 중..."

        do {
            // 첫 자동 동기화인지 확인
            let isFirstBackgroundSync = UserDefaults.standard.object(forKey: "lastBackgroundSyncAt") == nil

            if isFirstBackgroundSync {
                // 첫 자동 동기화시 전체 데이터
                print("[BackgroundTask] 첫 자동 동기화 - 전체 데이터 전송")
                let healthData = try await healthDataManager.readHealthData()
                try mcpClient.sendHealthDataInBackground(healthData)
            } else {
                // 이후에는 증분 데이터를 개별 전송
                let lastBackgroundSync = lastBackgroundSyncAt ?? Date.distantPast
                print("[BackgroundTask] 마지막 백그라운드 동기화: \(lastBackgroundSync)")

                try await healthDataManager.readAndSendIncrementalHealthData(since: lastBackgroundSync) { healthData in
                    try mcpClient.sendHealthDataInBackground(healthData)
                }
            }

            print("[BackgroundTask] 데이터 전송 완료")

            // 성공 시 상태 업데이트
            lastBackgroundSyncAt = Date()
            UserDefaults.standard.set(lastBackgroundSyncAt, forKey: "lastBackgroundSyncAt")
            backgroundSyncStatus = isFirstBackgroundSync ? "첫 전체 자동 동기화 완료" : "자동 증분 동기화 완료"

            print("[BackgroundTask] 헬스데이터 변경으로 인한 자동 동기화 성공")

        } catch {
            backgroundSyncStatus = "자동 동기화 실패: \(error.localizedDescription)"
            print("[BackgroundTask] 헬스데이터 자동 동기화 실패: \(error)")
        }
    }
}
