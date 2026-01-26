import AppIntents
import Foundation

/// AppIntent that triggers a refresh for Claude usage by notifying the main app
@available(macOS 14.0, *)
public struct RefreshUsageIntent: AppIntent {
    public static let title: LocalizedStringResource = "Refresh Claude Usage"
    public static let description: IntentDescription = IntentDescription("Fetches the latest Claude API usage data")

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        // Post a distributed notification to wake the main app
        DistributedNotificationCenter.default().postNotificationName(
            UsageProvider.claude.refreshNotificationName,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
        return .result()
    }
}

/// AppIntent that triggers a refresh for Codex usage by notifying the main app
@available(macOS 14.0, *)
public struct RefreshCodexUsageIntent: AppIntent {
    public static let title: LocalizedStringResource = "Refresh Codex Usage"
    public static let description: IntentDescription = IntentDescription("Fetches the latest Codex API usage data")

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        // Post a distributed notification to wake the main app
        DistributedNotificationCenter.default().postNotificationName(
            UsageProvider.codex.refreshNotificationName,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
        return .result()
    }
}

/// Notification names for refresh requests
public extension Notification.Name {
    static let refreshUsage = UsageProvider.claude.refreshNotificationName
    static let refreshCodexUsage = UsageProvider.codex.refreshNotificationName
}
