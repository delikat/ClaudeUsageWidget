import AppIntents
import Foundation

/// AppIntent that triggers a refresh for Claude usage by notifying the main app
@available(macOS 14.0, *)
public struct RefreshUsageIntent: AppIntent {
    public static let title: LocalizedStringResource = "Refresh Usage"
    public static let description: IntentDescription = IntentDescription("Fetches the latest usage data")

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

/// AppIntent that triggers a refresh for Claude monthly usage by notifying the main app
@available(macOS 14.0, *)
public struct RefreshMonthlyUsageIntent: AppIntent {
    public static let title: LocalizedStringResource = "Refresh Claude Monthly Usage"
    public static let description: IntentDescription = IntentDescription("Fetches the latest monthly Claude usage data from local logs")

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        DistributedNotificationCenter.default().postNotificationName(
            MonthlyUsageProvider.claude.refreshNotificationName,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
        return .result()
    }
}

/// AppIntent that triggers a refresh for Codex monthly usage by notifying the main app
@available(macOS 14.0, *)
public struct RefreshCodexMonthlyUsageIntent: AppIntent {
    public static let title: LocalizedStringResource = "Refresh Codex Monthly Usage"
    public static let description: IntentDescription = IntentDescription("Fetches the latest monthly Codex usage data from local logs")

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        DistributedNotificationCenter.default().postNotificationName(
            MonthlyUsageProvider.codex.refreshNotificationName,
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
    static let refreshMonthlyUsage = MonthlyUsageProvider.claude.refreshNotificationName
    static let refreshCodexMonthlyUsage = MonthlyUsageProvider.codex.refreshNotificationName
}
