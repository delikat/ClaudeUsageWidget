import AppIntents
import Foundation

/// AppIntent that triggers a refresh by notifying the main app
@available(macOS 14.0, *)
public struct RefreshUsageIntent: AppIntent {
    public static let title: LocalizedStringResource = "Refresh Claude Usage"
    public static let description: IntentDescription = IntentDescription("Fetches the latest Claude API usage data")

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        // Post a distributed notification to wake the main app
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("com.delikat.claudewidget.refresh"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
        return .result()
    }
}

/// Notification name for refresh requests
public extension Notification.Name {
    static let refreshUsage = Notification.Name("com.delikat.claudewidget.refresh")
}
