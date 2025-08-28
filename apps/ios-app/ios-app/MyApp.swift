import SwiftUI
import BackgroundTasks

@main
struct MyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            HealthSyncView()
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // 앱이 활성화될 때 백그라운드 작업 상태 체크
                    Task { @MainActor in
                        if BackgroundTaskManager.shared.isBackgroundSyncEnabled {
                            BackgroundTaskManager.shared.backgroundSyncStatus = "백그라운드 동기화 활성"
                        }
                    }
                }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    var backgroundCompletionHandler: (() -> Void)?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // 백그라운드 작업 스케줄러 초기화
        Task { @MainActor in
            let backgroundTaskManager = BackgroundTaskManager.shared
            if backgroundTaskManager.isBackgroundSyncEnabled {
                backgroundTaskManager.scheduleBackgroundSync()
            }
        }
        return true
    }

    func application(_ application: UIApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        print("[AppDelegate] handleEventsForBackgroundURLSession id=\(identifier)")
        backgroundCompletionHandler = completionHandler
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        print("[AppDelegate] 앱이 백그라운드로 이동")
        Task { @MainActor in
            BackgroundTaskManager.shared.handleAppDidEnterBackground()
        }
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        print("[AppDelegate] 앱이 포어그라운드로 복귀")
    }
}
