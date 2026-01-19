import Foundation

/// API response from https://api.anthropic.com/api/oauth/usage
public struct APIUsageResponse: Codable, Sendable {
    public let fiveHour: UsageMetric
    public let sevenDay: UsageMetric

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }

    public init(fiveHour: UsageMetric, sevenDay: UsageMetric) {
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
    }
}

/// Individual usage metric with utilization and reset time
public struct UsageMetric: Codable, Sendable {
    /// Utilization as a percentage (0 - 100)
    public let utilization: Double
    /// ISO8601 timestamp when usage resets, or null
    public let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }

    public init(utilization: Double, resetsAt: String?) {
        self.utilization = utilization
        self.resetsAt = resetsAt
    }
}

/// Credentials JSON structure from Claude Code keychain entry
public struct ClaudeCredentials: Codable, Sendable {
    public let claudeAiOauth: OAuthTokens

    public struct OAuthTokens: Codable, Sendable {
        public let accessToken: String

        enum CodingKeys: String, CodingKey {
            case accessToken
        }
    }
}
