import Foundation

public enum WidgetUpdateTimeFormatter {
    private static let secondsPerMinute: TimeInterval = 60
    private static let secondsPerHour: TimeInterval = 3600
    private static let secondsPerDay: TimeInterval = 86_400

    public static func formatUpdateTime(since date: Date, now: Date = Date()) -> String {
        let elapsed = now.timeIntervalSince(date)
        if elapsed < 0 {
            return "just now"
        }
        if elapsed < secondsPerMinute {
            return "just now"
        }
        if elapsed < secondsPerHour {
            let minutes = max(1, Int(elapsed / secondsPerMinute))
            return "\(minutes)m ago"
        }
        if elapsed < secondsPerDay {
            let hours = max(1, Int(elapsed / secondsPerHour))
            return "\(hours)h ago"
        }
        return "--"
    }
}
