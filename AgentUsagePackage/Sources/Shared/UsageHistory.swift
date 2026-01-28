import Foundation

/// Usage data for a single day
public struct DailyUsage: Codable, Sendable, Equatable {
    /// Date in "YYYY-MM-DD" format
    public let date: String
    /// Estimated tokens used by Claude conversations
    public let claudeTokens: Int
    /// Estimated tokens used by Codex conversations
    public let codexTokens: Int

    public init(date: String, claudeTokens: Int, codexTokens: Int) {
        self.date = date
        self.claudeTokens = claudeTokens
        self.codexTokens = codexTokens
    }

    /// Total tokens across both providers
    public var totalTokens: Int {
        claudeTokens + codexTokens
    }
}

/// Historical usage data for heatmap display
public struct UsageHistory: Codable, Sendable {
    /// Daily usage entries, sorted by date descending (most recent first)
    public var entries: [DailyUsage]

    public init(entries: [DailyUsage] = []) {
        self.entries = entries
    }

    /// Get usage for a specific date
    public func usage(for date: String) -> DailyUsage? {
        entries.first { $0.date == date }
    }

    /// Get entries for the last N days
    public func recentEntries(days: Int) -> [DailyUsage] {
        Array(entries.prefix(days))
    }

    /// Maximum tokens in any single day (for color scaling)
    public var maxDailyTokens: Int {
        entries.map(\.totalTokens).max() ?? 1
    }

    /// Placeholder data for widget previews
    public static var placeholder: UsageHistory {
        let calendar = Calendar.current
        let today = Date()

        var entries: [DailyUsage] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        for dayOffset in 0..<35 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let dateString = formatter.string(from: date)
            // Generate random-ish token counts for preview
            let claudeTokens = (dayOffset % 7 == 0) ? 0 : Int.random(in: 1000...50000)
            let codexTokens = (dayOffset % 5 == 0) ? 0 : Int.random(in: 500...20000)
            entries.append(DailyUsage(date: dateString, claudeTokens: claudeTokens, codexTokens: codexTokens))
        }

        return UsageHistory(entries: entries)
    }
}

/// Manages reading and writing usage history to App Group container
public final class UsageHistoryManager: Sendable {
    public static let shared = UsageHistoryManager()

    private let fileName = "UsageHistory.json"
    private let appGroupIdentifier = AppGroup.identifier

    private var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(fileName)
    }

    private init() {}

    /// Read usage history from App Group container
    public func read() -> UsageHistory? {
        guard let url = fileURL else {
            AppLog.history.error("UsageHistoryManager: Could not get App Group container URL")
            return nil
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(UsageHistory.self, from: data)
        } catch {
            AppLog.history.error("UsageHistoryManager: Failed to read history: \(error.localizedDescription)")
            return nil
        }
    }

    /// Write usage history to App Group container
    public func write(_ history: UsageHistory) throws {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            AppLog.history.error("UsageHistoryManager: containerURL returned nil for \(self.appGroupIdentifier)")
            throw HistoryWriteError.noContainerURL
        }

        // Ensure the container directory exists
        if !FileManager.default.fileExists(atPath: containerURL.path) {
            try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
            AppLog.history.info("UsageHistoryManager: Created container directory at \(containerURL.path)")
        }

        let url = containerURL.appendingPathComponent(fileName)
        AppLog.history.debug("UsageHistoryManager: Writing history to \(url.path)")

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        let data = try encoder.encode(history)
        try data.write(to: url, options: .atomic)
        AppLog.history.info("UsageHistoryManager: Successfully wrote history with \(history.entries.count) entries")
    }

    public enum HistoryWriteError: Error {
        case noContainerURL
    }
}
