import SwiftUI
import Shared

@main
struct AgentUsageApp: App {
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
    private var historyTimer: Timer?
    private var claudeNotificationObserver: Any?
    private var codexNotificationObserver: Any?
    private var claudeMonthlyNotificationObserver: Any?
    private var codexMonthlyNotificationObserver: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLog.app.info("AgentUsage: App launched")

        // Request notification permission for usage alerts
        NotificationManager.shared.requestPermission()

        // Listen for Claude refresh notifications from widget
        claudeNotificationObserver = DistributedNotificationCenter.default().addObserver(
            forName: .refreshUsage,
            object: nil,
            queue: .main
        ) { _ in
            AppLog.app.info("AgentUsage: Received Claude refresh notification from widget")
            Task {
                await UsageService.shared.fetchAndCache()
                await ClaudeJSONLService.shared.fetchAndCache()
            }
        }

        // Listen for Codex refresh notifications from widget
        codexNotificationObserver = DistributedNotificationCenter.default().addObserver(
            forName: .refreshCodexUsage,
            object: nil,
            queue: .main
        ) { _ in
            AppLog.app.info("AgentUsage: Received Codex refresh notification from widget")
            Task {
                await self.refreshCodexIfAvailable()
                await CodexJSONLService.shared.fetchAndCache()
            }
        }

        // Listen for Claude monthly refresh notifications from widget
        claudeMonthlyNotificationObserver = DistributedNotificationCenter.default().addObserver(
            forName: .refreshMonthlyUsage,
            object: nil,
            queue: .main
        ) { _ in
            AppLog.app.info("AgentUsage: Received Claude monthly refresh notification from widget")
            Task {
                await UsageService.shared.fetchAndCache()
                await ClaudeJSONLService.shared.fetchAndCache()
            }
        }

        // Listen for Codex monthly refresh notifications from widget
        codexMonthlyNotificationObserver = DistributedNotificationCenter.default().addObserver(
            forName: .refreshCodexMonthlyUsage,
            object: nil,
            queue: .main
        ) { _ in
            AppLog.app.info("AgentUsage: Received Codex monthly refresh notification from widget")
            Task {
                await self.refreshCodexIfAvailable()
                await CodexJSONLService.shared.fetchAndCache()
            }
        }

        // Initial fetch for both services
        refreshAll()

        // Schedule periodic refresh every 15 minutes
        schedulePeriodicRefresh()

        // Initial history update (scans JSONL files for heatmap)
        Task {
            await HistoryService.shared.updateHistory()
        }

        // Schedule periodic history updates (every hour)
        scheduleHistoryUpdates()
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
        historyTimer?.invalidate()
        if let observer = claudeNotificationObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        if let observer = codexNotificationObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        if let observer = claudeMonthlyNotificationObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        if let observer = codexMonthlyNotificationObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    private func schedulePeriodicRefresh() {
        // Refresh every 15 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { _ in
            AppLog.app.debug("AgentUsage: Periodic refresh triggered")
            self.refreshAll()
        }
    }

    private func scheduleHistoryUpdates() {
        // Update history every hour (HistoryService has internal throttling too)
        historyTimer = Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { _ in
            AppLog.app.debug("AgentUsage: Periodic history update triggered")
            Task {
                await HistoryService.shared.updateHistory()
            }
        }
    }

    private func refreshAll() {
        Task {
            async let claudeRefresh = UsageService.shared.fetchAndCache()
            async let codexRefresh = refreshCodexIfAvailable()
            async let claudeMonthlyRefresh = ClaudeJSONLService.shared.fetchAndCache()
            async let codexMonthlyRefresh = CodexJSONLService.shared.fetchAndCache()
            _ = await (claudeRefresh, codexRefresh, claudeMonthlyRefresh, codexMonthlyRefresh)
        }
    }

    private func refreshCodexIfAvailable() async {
        guard CodexCredentials.hasCredentials() else {
            AppLog.app.debug("AgentUsage: Skipping Codex refresh (no credentials)")
            return
        }
        await CodexUsageService.shared.fetchAndCache()
    }
}
