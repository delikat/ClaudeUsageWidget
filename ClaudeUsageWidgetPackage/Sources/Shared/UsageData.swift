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
        public let expiresAt: Int64?  // Unix timestamp in milliseconds (optional for backwards compat)
        public let subscriptionType: String?  // e.g., "max", "pro"
        public let rateLimitTier: String?  // e.g., "default_claude_max_20x", "default_claude_max_5x"

        enum CodingKeys: String, CodingKey {
            case accessToken
            case expiresAt
            case subscriptionType
            case rateLimitTier
        }

        /// Formatted display name for the subscription tier
        /// Parses rateLimitTier like "default_claude_max_20x" → "Max 20x"
        /// Falls back to subscriptionType like "max" → "Max"
        public var displayTier: String? {
            if let tier = rateLimitTier {
                // Parse "default_claude_max_20x" → "Max 20x"
                // Parse "default_claude_max_5x" → "Max 5x"
                // Parse "default_claude_pro" → "Pro"
                let cleaned = tier
                    .replacingOccurrences(of: "default_claude_", with: "")
                    .replacingOccurrences(of: "_", with: " ")
                    .split(separator: " ")
                    .map { word in
                        // Keep "5x", "20x" lowercase after the number
                        if word.first?.isNumber == true {
                            return String(word)
                        }
                        return word.capitalized
                    }
                    .joined(separator: " ")
                return cleaned.isEmpty ? nil : cleaned
            }
            // Fall back to subscriptionType
            if let sub = subscriptionType {
                return sub.capitalized
            }
            return nil
        }
    }
}
