import Foundation
import Shared
import UserNotifications
import Shared

/// Notification thresholds and provider info
enum NotificationProvider: String {
    case claude
    case codex

    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        }
    }
}

/// Manages usage alert notifications for both Claude and Codex
final class NotificationManager: @unchecked Sendable {
    static let shared = NotificationManager()

    /// Thresholds for notifications
    private let warningThreshold: Double = 80.0
    private let criticalThreshold: Double = 95.0

    /// Track notified states to prevent spam
    /// Format: "provider-window-threshold" e.g., "claude-5h-80", "codex-7d-95"
    private var notifiedThresholds: Set<String> = []
    private let lock = NSLock()

    private init() {}

    /// Request notification permission from the user
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                AppLog.notifications.info("NotificationManager: Notification permission granted")
            } else if let error = error {
                AppLog.notifications.error("NotificationManager: Permission error: \(error.localizedDescription)")
            } else {
                AppLog.notifications.info("NotificationManager: Notification permission denied")
            }
        }
    }

    /// Check usage and notify if thresholds exceeded
    /// - Parameters:
    ///   - fiveHourUsage: 5-hour usage percentage (0-100)
    ///   - sevenDayUsage: 7-day usage percentage (0-100)
    ///   - fiveHourResetAt: When 5-hour window resets
    ///   - sevenDayResetAt: When 7-day window resets
    ///   - hasError: Whether there was an error fetching usage
    ///   - provider: Which provider this usage is for
    func checkAndNotify(
        fiveHourUsage: Double,
        sevenDayUsage: Double,
        fiveHourResetAt: Date?,
        sevenDayResetAt: Date?,
        hasError: Bool,
        provider: NotificationProvider
    ) {
        // Don't notify on error states
        guard !hasError else { return }

        // Check 5-hour window
        checkThreshold(
            value: fiveHourUsage,
            window: "5h",
            windowLabel: "5-hour",
            provider: provider,
            resetAt: fiveHourResetAt
        )

        // Check 7-day window
        checkThreshold(
            value: sevenDayUsage,
            window: "7d",
            windowLabel: "7-day",
            provider: provider,
            resetAt: sevenDayResetAt
        )
    }

    /// Reset notification state when usage drops below thresholds
    func resetIfNeeded(fiveHourUsage: Double, sevenDayUsage: Double, provider: NotificationProvider) {
        lock.lock()
        defer { lock.unlock() }

        let providerKey = provider.rawValue

        // Reset 5-hour notifications if usage dropped below thresholds
        if fiveHourUsage < warningThreshold {
            notifiedThresholds.remove("\(providerKey)-5h-80")
            notifiedThresholds.remove("\(providerKey)-5h-95")
        } else if fiveHourUsage < criticalThreshold {
            notifiedThresholds.remove("\(providerKey)-5h-95")
        }

        // Reset 7-day notifications if usage dropped below thresholds
        if sevenDayUsage < warningThreshold {
            notifiedThresholds.remove("\(providerKey)-7d-80")
            notifiedThresholds.remove("\(providerKey)-7d-95")
        } else if sevenDayUsage < criticalThreshold {
            notifiedThresholds.remove("\(providerKey)-7d-95")
        }
    }

    private func checkThreshold(
        value: Double,
        window: String,
        windowLabel: String,
        provider: NotificationProvider,
        resetAt: Date?
    ) {
        lock.lock()
        defer { lock.unlock() }

        let providerKey = provider.rawValue

        // Check critical threshold first (95%)
        if value >= criticalThreshold {
            let key = "\(providerKey)-\(window)-95"
            if !notifiedThresholds.contains(key) {
                notifiedThresholds.insert(key)
                sendNotification(
                    title: "\(provider.displayName) Usage Critical",
                    body: "\(windowLabel) usage at \(Int(value))%",
                    identifier: key,
                    isCritical: true,
                    resetAt: resetAt
                )
            }
        }
        // Check warning threshold (80%)
        else if value >= warningThreshold {
            let key = "\(providerKey)-\(window)-80"
            if !notifiedThresholds.contains(key) {
                notifiedThresholds.insert(key)
                sendNotification(
                    title: "\(provider.displayName) Usage Warning",
                    body: "\(windowLabel) usage at \(Int(value))%",
                    identifier: key,
                    isCritical: false,
                    resetAt: resetAt
                )
            }
        }
    }

    private func sendNotification(
        title: String,
        body: String,
        identifier: String,
        isCritical: Bool,
        resetAt: Date?
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        // Add reset time to body if available
        if let resetAt = resetAt {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            let relativeTime = formatter.localizedString(for: resetAt, relativeTo: Date())
            content.body = "\(body). Resets \(relativeTime)"
        }

        content.sound = isCritical ? .defaultCritical : .default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil  // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                AppLog.notifications.error("NotificationManager: Failed to send notification: \(error.localizedDescription)")
            } else {
                AppLog.notifications.info("NotificationManager: Sent notification: \(title)")
            }
        }
    }
}
