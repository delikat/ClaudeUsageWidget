import SwiftUI
import Shared

@main
struct AgentUsageWidgetApp: App {
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
    @State private var automaticallyCheckForUpdates: Bool = UpdateManager.shared.automaticallyChecks
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

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

            Divider()

            HStack {
                Text("Version")
                Spacer()
                Text("v\(appVersion) (\(buildNumber))")
                    .foregroundColor(.secondary)
            }

            Button("Check for Updates...") {
                UpdateManager.shared.checkForUpdates()
            }

            Toggle("Automatically check for updates", isOn: $automaticallyCheckForUpdates)
                .onChange(of: automaticallyCheckForUpdates) { _, newValue in
                    UpdateManager.shared.automaticallyChecks = newValue
                }
        }
        .padding(20)
        .frame(width: 350, height: 180)
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

    // Keep strong reference to update manager
    private let updateManager = UpdateManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLog.app.info("AgentUsageWidget: App launched")

        // Initialize Sparkle updates (already starts via shared singleton)
        _ = updateManager

        // Request notification permission for usage alerts
        NotificationManager.shared.requestPermission()

        // Listen for Claude refresh notifications from widget
        claudeNotificationObserver = DistributedNotificationCenter.default().addObserver(
            forName: .refreshUsage,
            object: nil,
            queue: .main
        ) { _ in
            AppLog.app.info("AgentUsageWidget: Received Claude refresh notification from widget")
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
            AppLog.app.info("AgentUsageWidget: Received Codex refresh notification from widget")
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
            AppLog.app.info("AgentUsageWidget: Received Claude monthly refresh notification from widget")
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
            AppLog.app.info("AgentUsageWidget: Received Codex monthly refresh notification from widget")
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
            AppLog.app.debug("AgentUsageWidget: Periodic refresh triggered")
            self.refreshAll()
        }
    }

    private func scheduleHistoryUpdates() {
        // Update history every hour (HistoryService has internal throttling too)
        historyTimer = Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { _ in
            AppLog.app.debug("AgentUsageWidget: Periodic history update triggered")
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
            AppLog.app.debug("AgentUsageWidget: Skipping Codex refresh (no credentials)")
            return
        }
        await CodexUsageService.shared.fetchAndCache()
    }
}
