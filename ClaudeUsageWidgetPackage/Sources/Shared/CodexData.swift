import Foundation

/// Credentials from ~/.codex/auth.json
public struct CodexCredentials: Codable, Sendable {
    public let openaiApiKey: String?
    public let tokens: CodexTokens?
    public let lastRefresh: String?

    enum CodingKeys: String, CodingKey {
        case openaiApiKey = "OPENAI_API_KEY"
        case tokens
        case lastRefresh = "last_refresh"
    }

    public struct CodexTokens: Codable, Sendable {
        public let accessToken: String
        public let refreshToken: String?
        public let accountId: String
        public let idToken: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case accountId = "account_id"
            case idToken = "id_token"
        }
    }

    /// Load credentials from ~/.codex/auth.json
    public static func load() throws -> CodexCredentials {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let authPath = homeDir.appendingPathComponent(".codex/auth.json")

        guard FileManager.default.fileExists(atPath: authPath.path) else {
            throw CodexCredentialsError.fileNotFound
        }

        let data = try Data(contentsOf: authPath)
        return try JSONDecoder().decode(CodexCredentials.self, from: data)
    }
}

public enum CodexCredentialsError: Error {
    case fileNotFound
    case missingTokens
}

/// API response from https://chatgpt.com/backend-api/wham/usage
public struct CodexUsageResponse: Codable, Sendable {
    public let planType: String
    public let rateLimit: CodexRateLimit
    public let credits: CodexCredits

    enum CodingKeys: String, CodingKey {
        case planType = "plan_type"
        case rateLimit = "rate_limit"
        case credits
    }
}

public struct CodexRateLimit: Codable, Sendable {
    public let allowed: Bool
    public let limitReached: Bool
    public let primaryWindow: CodexUsageWindow
    public let secondaryWindow: CodexUsageWindow

    enum CodingKeys: String, CodingKey {
        case allowed
        case limitReached = "limit_reached"
        case primaryWindow = "primary_window"
        case secondaryWindow = "secondary_window"
    }
}

public struct CodexUsageWindow: Codable, Sendable {
    /// Usage percentage (0-100)
    public let usedPercent: Int
    /// Window duration in seconds (e.g., 18000 for 5 hours)
    public let limitWindowSeconds: Int
    /// Seconds until reset
    public let resetAfterSeconds: Int
    /// Unix timestamp when usage resets
    public let resetAt: Int64

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case limitWindowSeconds = "limit_window_seconds"
        case resetAfterSeconds = "reset_after_seconds"
        case resetAt = "reset_at"
    }
}

public struct CodexCredits: Codable, Sendable {
    public let hasCredits: Bool
    public let unlimited: Bool
    public let balance: String

    enum CodingKeys: String, CodingKey {
        case hasCredits = "has_credits"
        case unlimited
        case balance
    }
}
