import SwiftUI
import Shared

@main
struct ClaudeUsageWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible window - this is an invisible background app
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var refreshTimer: Timer?
    private var notificationObserver: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("ClaudeUsageWidget: App launched")

        // Listen for refresh notifications from widget
        notificationObserver = DistributedNotificationCenter.default().addObserver(
            forName: .refreshUsage,
            object: nil,
            queue: .main
        ) { _ in
            print("ClaudeUsageWidget: Received refresh notification from widget")
            Task { @MainActor in
                await UsageService.shared.fetchAndCache()
            }
        }

        // Initial fetch
        Task { @MainActor in
            await UsageService.shared.fetchAndCache()
        }

        // Schedule periodic refresh every 15 minutes
        schedulePeriodicRefresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
        if let observer = notificationObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    private func schedulePeriodicRefresh() {
        // Refresh every 15 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { _ in
            print("ClaudeUsageWidget: Periodic refresh triggered")
            Task { @MainActor in
                await UsageService.shared.fetchAndCache()
            }
        }
    }
}
