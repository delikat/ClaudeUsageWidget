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
    @State private var codexAuthMethod: CodexAuthMethod = CodexSettingsStore.shared.authMethod
    @State private var codexModelFilter: String = CodexSettingsStore.shared.modelFilter
    @State private var codexProjectFilter: String = CodexSettingsStore.shared.projectFilter
    @State private var codexExperimentalEnabled: Bool = CodexSettingsStore.shared.enableExperimentalSubscription
    @State private var codexSubscriptionAuthMode: CodexSubscriptionAuthMode = CodexSettingsStore.shared.subscriptionAuthMode
    @State private var codexApiKey: String = ""
    @State private var codexSessionToken: String = ""
    @State private var hasCodexApiKey: Bool = false
    @State private var hasCodexSessionToken: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        Form {
            Section("App") {
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

            Section("Codex Usage") {
                Picker("Auth Method", selection: $codexAuthMethod) {
                    Text("API Key").tag(CodexAuthMethod.apiKey)
                    Text("ChatGPT Plan (Experimental)").tag(CodexAuthMethod.chatgptSession)
                }
                .onChange(of: codexAuthMethod) { _, newValue in
                    CodexSettingsStore.shared.authMethod = newValue
                }

                Toggle("Enable Experimental Endpoint", isOn: $codexExperimentalEnabled)
                    .onChange(of: codexExperimentalEnabled) { _, newValue in
                        CodexSettingsStore.shared.enableExperimentalSubscription = newValue
                    }

                if codexAuthMethod == .apiKey {
                    SecureField("OpenAI API Key", text: $codexApiKey)
                    HStack {
                        Button("Save API Key") {
                            saveCodexAPIKey()
                        }
                        Button("Clear") {
                            clearCodexAPIKey()
                        }
                    }
                    if hasCodexApiKey {
                        Text("API key saved in Keychain")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    TextField("Model filter (comma separated)", text: $codexModelFilter)
                        .onChange(of: codexModelFilter) { _, newValue in
                            CodexSettingsStore.shared.modelFilter = newValue
                        }

                    TextField("Project filter (comma separated)", text: $codexProjectFilter)
                        .onChange(of: codexProjectFilter) { _, newValue in
                            CodexSettingsStore.shared.projectFilter = newValue
                        }
                } else {
                    Picker("Auth Header", selection: $codexSubscriptionAuthMode) {
                        Text("Cookie").tag(CodexSubscriptionAuthMode.cookie)
                        Text("Bearer Token").tag(CodexSubscriptionAuthMode.bearer)
                    }
                    .onChange(of: codexSubscriptionAuthMode) { _, newValue in
                        CodexSettingsStore.shared.subscriptionAuthMode = newValue
                    }

                    SecureField("Session Token or Cookie", text: $codexSessionToken)
                    HStack {
                        Button("Save Session Token") {
                            saveCodexSessionToken()
                        }
                        Button("Clear") {
                            clearCodexSessionToken()
                        }
                    }
                    if hasCodexSessionToken {
                        Text("Session token saved in Keychain")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 420, height: 480)
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            refreshCodexCredentialStatus()
        }
    }

    private func refreshCodexCredentialStatus() {
        do {
            hasCodexApiKey = (try KeychainStore.shared.readPassword(service: CodexKeychain.service, account: CodexKeychain.apiKeyAccount))?.isEmpty == false
            hasCodexSessionToken = (try KeychainStore.shared.readPassword(service: CodexKeychain.service, account: CodexKeychain.sessionTokenAccount))?.isEmpty == false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func saveCodexAPIKey() {
        do {
            if codexApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try KeychainStore.shared.deletePassword(service: CodexKeychain.service, account: CodexKeychain.apiKeyAccount)
            } else {
                try KeychainStore.shared.savePassword(codexApiKey, service: CodexKeychain.service, account: CodexKeychain.apiKeyAccount)
            }
            codexApiKey = ""
            refreshCodexCredentialStatus()
            Task {
                await CodexUsageService.shared.fetchAndCache()
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func clearCodexAPIKey() {
        do {
            try KeychainStore.shared.deletePassword(service: CodexKeychain.service, account: CodexKeychain.apiKeyAccount)
            refreshCodexCredentialStatus()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func saveCodexSessionToken() {
        do {
            if codexSessionToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try KeychainStore.shared.deletePassword(service: CodexKeychain.service, account: CodexKeychain.sessionTokenAccount)
            } else {
                try KeychainStore.shared.savePassword(codexSessionToken, service: CodexKeychain.service, account: CodexKeychain.sessionTokenAccount)
            }
            codexSessionToken = ""
            refreshCodexCredentialStatus()
            Task {
                await CodexUsageService.shared.fetchAndCache()
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func clearCodexSessionToken() {
        do {
            try KeychainStore.shared.deletePassword(service: CodexKeychain.service, account: CodexKeychain.sessionTokenAccount)
            refreshCodexCredentialStatus()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
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
            Task {
                await UsageService.shared.fetchAndCache()
                await CodexUsageService.shared.fetchAndCache()
            }
        }

        // Initial fetch
        Task {
            await UsageService.shared.fetchAndCache()
            await CodexUsageService.shared.fetchAndCache()
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
            Task {
                await UsageService.shared.fetchAndCache()
                await CodexUsageService.shared.fetchAndCache()
            }
        }
    }
}
