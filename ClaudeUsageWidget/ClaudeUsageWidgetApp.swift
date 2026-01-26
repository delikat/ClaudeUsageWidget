import SwiftUI
import Shared

@main
struct ClaudeUsageWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible window - this is an invisible background app
        Settings {
            SettingsView()
        }
    }
}

struct SettingsView: View {
    @State private var startAtLogin: Bool = LaunchAgentManager.shared.isEnabled
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        Form {
            Toggle("Start at Login", isOn: $startAtLogin)
                .onChange(of: startAtLogin) { _, newValue in
                    do {
                        try LaunchAgentManager.shared.setEnabled(newValue)
                    } catch {
                        errorMessage = error.localizedDescription
                        showError = true
                        // Revert the toggle
                        startAtLogin = !newValue
                    }
                }
        }
        .padding(20)
        .frame(width: 300, height: 100)
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var refreshTimer: Timer?
    private var claudeNotificationObserver: Any?
    private var codexNotificationObserver: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("ClaudeUsageWidget: App launched")

        // Listen for Claude refresh notifications from widget
        claudeNotificationObserver = DistributedNotificationCenter.default().addObserver(
            forName: .refreshUsage,
            object: nil,
            queue: .main
        ) { _ in
            print("ClaudeUsageWidget: Received Claude refresh notification from widget")
            Task {
                await UsageService.shared.fetchAndCache()
            }
        }

        // Listen for Codex refresh notifications from widget
        codexNotificationObserver = DistributedNotificationCenter.default().addObserver(
            forName: .refreshCodexUsage,
            object: nil,
            queue: .main
        ) { _ in
            print("ClaudeUsageWidget: Received Codex refresh notification from widget")
            Task {
                await CodexUsageService.shared.fetchAndCache()
            }
        }

        // Initial fetch for both services
        Task {
            await UsageService.shared.fetchAndCache()
            await CodexUsageService.shared.fetchAndCache()
        }

        // Schedule periodic refresh every 15 minutes
        schedulePeriodicRefresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
        if let observer = claudeNotificationObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        if let observer = codexNotificationObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    private func schedulePeriodicRefresh() {
        // Refresh every 15 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { _ in
            print("ClaudeUsageWidget: Periodic refresh triggered")
            Task {
                await UsageService.shared.fetchAndCache()
                await CodexUsageService.shared.fetchAndCache()
            }
        }
    }
}
