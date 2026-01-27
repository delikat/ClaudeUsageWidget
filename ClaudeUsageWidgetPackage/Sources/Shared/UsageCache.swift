import Foundation

/// Cached usage data written by main app, read by widget
public struct CachedUsage: Codable, Sendable {
    /// 5-hour usage as percentage (0-100)
    public let fiveHourUsage: Double
    /// When 5-hour usage resets
    public let fiveHourResetAt: Date?
    /// 7-day usage as percentage (0-100)
    public let sevenDayUsage: Double
    /// When 7-day usage resets
    public let sevenDayResetAt: Date?
    /// When this data was fetched
    public let fetchedAt: Date
    /// Error state if fetch failed
    public let error: CacheError?
    /// Formatted subscription tier for display (e.g., "Max 20x", "Pro")
    public let planTitle: String?

    public enum CacheError: String, Codable, Sendable {
        case noCredentials
        case networkError
        case invalidToken
        case apiError
        case invalidCredentialsFormat
    }

    public init(
        fiveHourUsage: Double,
        fiveHourResetAt: Date?,
        sevenDayUsage: Double,
        sevenDayResetAt: Date?,
        fetchedAt: Date,
        error: CacheError?,
        planTitle: String? = nil
    ) {
        self.fiveHourUsage = fiveHourUsage
        self.fiveHourResetAt = fiveHourResetAt
        self.sevenDayUsage = sevenDayUsage
        self.sevenDayResetAt = sevenDayResetAt
        self.fetchedAt = fetchedAt
        self.error = error
        self.planTitle = planTitle
    }

    /// Placeholder data for widget previews
    public static var placeholder: CachedUsage {
        CachedUsage(
            fiveHourUsage: 45.0,
            fiveHourResetAt: Date().addingTimeInterval(3600),
            sevenDayUsage: 23.0,
            sevenDayResetAt: Date().addingTimeInterval(86400),
            fetchedAt: Date(),
            error: nil,
            planTitle: "Max 20x"
        )
    }

    /// Error state for when credentials are missing
    public static var noCredentialsError: CachedUsage {
        CachedUsage(
            fiveHourUsage: 0,
            fiveHourResetAt: nil,
            sevenDayUsage: 0,
            sevenDayResetAt: nil,
            fetchedAt: Date(),
            error: .noCredentials,
            planTitle: nil
        )
    }
}

/// Provider type for usage cache
public enum UsageProvider: String, Sendable {
    case claude
    case codex

    var fileName: String {
        switch self {
        case .claude:
            return "UsageCache.json"
        case .codex:
            return "CodexUsageCache.json"
        }
    }

    /// Distributed notification name for refresh requests
    public var refreshNotificationName: Notification.Name {
        switch self {
        case .claude:
            return Notification.Name("com.delikat.claudewidget.refresh")
        case .codex:
            return Notification.Name("com.delikat.claudewidget.codex.refresh")
        }
    }
}

/// Provider type for monthly usage cache
public enum MonthlyUsageProvider: String, Sendable {
    case claude
    case codex

    var fileName: String {
        switch self {
        case .claude:
            return "ClaudeMonthlyUsage.json"
        case .codex:
            return "CodexMonthlyUsage.json"
        }
    }

    /// Distributed notification name for monthly refresh requests
    public var refreshNotificationName: Notification.Name {
        switch self {
        case .claude:
            return Notification.Name("com.delikat.claudewidget.monthly.refresh")
        case .codex:
            return Notification.Name("com.delikat.claudewidget.codex.monthly.refresh")
        }
    }
}

/// Manages reading and writing cached usage data to App Group container
public final class UsageCacheManager: Sendable {
    /// Shared instance for Claude (backwards compatible)
    public static let shared = UsageCacheManager(provider: .claude)
    /// Shared instance for Codex
    public static let codex = UsageCacheManager(provider: .codex)

    public let provider: UsageProvider
    private let appGroupIdentifier = AppGroup.identifier

    private var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(provider.fileName)
    }

    public init(provider: UsageProvider) {
        self.provider = provider
    }

    /// Read cached usage data from App Group container
    public func read() -> CachedUsage? {
        guard let url = fileURL else {
            print("UsageCacheManager: Could not get App Group container URL")
            return nil
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(CachedUsage.self, from: data)
        } catch {
            print("UsageCacheManager: Failed to read cache: \(error)")
            return nil
        }
    }

    /// Write cached usage data to App Group container
    public func write(_ cache: CachedUsage) throws {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            print("UsageCacheManager: ERROR - containerURL returned nil for \(appGroupIdentifier)")
            throw CacheWriteError.noContainerURL
        }

        // Ensure the container directory exists
        if !FileManager.default.fileExists(atPath: containerURL.path) {
            try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
            print("UsageCacheManager: Created container directory at \(containerURL.path)")
        }

        let url = containerURL.appendingPathComponent(provider.fileName)
        print("UsageCacheManager: Writing cache to \(url.path)")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        let data = try encoder.encode(cache)
        try data.write(to: url, options: .atomic)
        print("UsageCacheManager: Successfully wrote cache")
    }

    public enum CacheWriteError: Error {
        case noContainerURL
    }
}

/// Manages reading and writing cached monthly usage data to App Group container
public final class MonthlyUsageCacheManager: Sendable {
    public static let claude = MonthlyUsageCacheManager(provider: .claude)
    public static let codex = MonthlyUsageCacheManager(provider: .codex)

    public let provider: MonthlyUsageProvider
    private let appGroupIdentifier = AppGroup.identifier

    private var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(provider.fileName)
    }

    public init(provider: MonthlyUsageProvider) {
        self.provider = provider
    }

    public func read() -> CachedMonthlyUsage? {
        guard let url = fileURL else {
            print("MonthlyUsageCacheManager: Could not get App Group container URL")
            return nil
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(CachedMonthlyUsage.self, from: data)
        } catch {
            print("MonthlyUsageCacheManager: Failed to read cache: \(error)")
            return nil
        }
    }

    public func write(_ cache: CachedMonthlyUsage) throws {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            print("MonthlyUsageCacheManager: ERROR - containerURL returned nil for \(appGroupIdentifier)")
            throw UsageCacheManager.CacheWriteError.noContainerURL
        }

        if !FileManager.default.fileExists(atPath: containerURL.path) {
            try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
            print("MonthlyUsageCacheManager: Created container directory at \(containerURL.path)")
        }

        let url = containerURL.appendingPathComponent(provider.fileName)
        print("MonthlyUsageCacheManager: Writing cache to \(url.path)")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        let data = try encoder.encode(cache)
        try data.write(to: url, options: .atomic)
        print("MonthlyUsageCacheManager: Successfully wrote cache")
    }
}
