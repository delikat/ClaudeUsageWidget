import Foundation

public struct CodexUsageWindow: Codable, Sendable {
    public let usedPercent: Double?
    public let tokens: Int?
    public let requests: Int?
    public let resetsAt: Date?
    public let windowStart: Date?
    public let windowEnd: Date?

    public init(
        usedPercent: Double? = nil,
        tokens: Int? = nil,
        requests: Int? = nil,
        resetsAt: Date? = nil,
        windowStart: Date? = nil,
        windowEnd: Date? = nil
    ) {
        self.usedPercent = usedPercent
        self.tokens = tokens
        self.requests = requests
        self.resetsAt = resetsAt
        self.windowStart = windowStart
        self.windowEnd = windowEnd
    }
}

public struct CodexCachedUsage: Codable, Sendable {
    public let primaryWindow: CodexUsageWindow
    public let secondaryWindow: CodexUsageWindow
    public let fetchedAt: Date
    public let error: CacheError?
    public let planTitle: String?

    public enum CacheError: String, Codable, Sendable {
        case noCredentials
        case invalidCredentials
        case networkError
        case apiError
        case invalidResponse
        case unsupported
    }

    public init(
        primaryWindow: CodexUsageWindow,
        secondaryWindow: CodexUsageWindow,
        fetchedAt: Date,
        error: CacheError?,
        planTitle: String?
    ) {
        self.primaryWindow = primaryWindow
        self.secondaryWindow = secondaryWindow
        self.fetchedAt = fetchedAt
        self.error = error
        self.planTitle = planTitle
    }

    public static var placeholder: CodexCachedUsage {
        CodexCachedUsage(
            primaryWindow: CodexUsageWindow(usedPercent: 42, resetsAt: Date().addingTimeInterval(3600)),
            secondaryWindow: CodexUsageWindow(usedPercent: 18, resetsAt: Date().addingTimeInterval(86400)),
            fetchedAt: Date(),
            error: nil,
            planTitle: "Pro"
        )
    }

    public static var noCredentialsError: CodexCachedUsage {
        CodexCachedUsage(
            primaryWindow: CodexUsageWindow(),
            secondaryWindow: CodexUsageWindow(),
            fetchedAt: Date(),
            error: .noCredentials,
            planTitle: nil
        )
    }
}
