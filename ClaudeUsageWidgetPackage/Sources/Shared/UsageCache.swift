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

/// Manages reading and writing cached usage data to App Group container
public final class UsageCacheManager: Sendable {
    public static let shared = UsageCacheManager()

    private let appGroupIdentifier = "HN6S8N7886.group.com.delikat.claudewidget"
    private let fileName = "UsageCache.json"

    private var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(fileName)
    }

    private init() {}

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

        let url = containerURL.appendingPathComponent(fileName)
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
