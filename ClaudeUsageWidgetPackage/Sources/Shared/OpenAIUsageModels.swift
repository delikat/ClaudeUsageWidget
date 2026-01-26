import Foundation

public struct OpenAIUsagePage: Decodable, Sendable {
    public let data: [OpenAIUsageBucket]
    public let hasMore: Bool?
    public let nextPage: String?

    enum CodingKeys: String, CodingKey {
        case data
        case hasMore = "has_more"
        case nextPage = "next_page"
    }
}

public struct OpenAIUsageBucket: Decodable, Sendable {
    public let startTime: Int
    public let endTime: Int
    public let results: [OpenAIUsageResult]

    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
        case results
        case result
    }

    public init(startTime: Int, endTime: Int, results: [OpenAIUsageResult]) {
        self.startTime = startTime
        self.endTime = endTime
        self.results = results
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        startTime = try container.decode(Int.self, forKey: .startTime)
        endTime = try container.decode(Int.self, forKey: .endTime)
        if let results = try container.decodeIfPresent([OpenAIUsageResult].self, forKey: .results) {
            self.results = results
        } else if let results = try container.decodeIfPresent([OpenAIUsageResult].self, forKey: .result) {
            self.results = results
        } else {
            self.results = []
        }
    }
}

public struct OpenAIUsageResult: Decodable, Sendable {
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let inputCachedTokens: Int?
    public let inputAudioTokens: Int?
    public let outputAudioTokens: Int?
    public let numModelRequests: Int?
    public let projectId: String?
    public let userId: String?
    public let apiKeyId: String?
    public let model: String?
    public let batch: Bool?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case inputCachedTokens = "input_cached_tokens"
        case inputAudioTokens = "input_audio_tokens"
        case outputAudioTokens = "output_audio_tokens"
        case numModelRequests = "num_model_requests"
        case projectId = "project_id"
        case userId = "user_id"
        case apiKeyId = "api_key_id"
        case model
        case batch
    }
}

public struct CodexSubscriptionUsageResponse: Codable, Sendable {
    public let planType: String?
    public let rateLimit: RateLimit?

    enum CodingKeys: String, CodingKey {
        case planType = "plan_type"
        case rateLimit = "rate_limit"
    }

    public struct RateLimit: Codable, Sendable {
        public let primaryWindow: RateLimitWindow?
        public let secondaryWindow: RateLimitWindow?

        enum CodingKeys: String, CodingKey {
            case primaryWindow = "primary_window"
            case secondaryWindow = "secondary_window"
        }
    }

    public struct RateLimitWindow: Codable, Sendable {
        public let windowSizeInHours: Int?
        public let windowSizeInDays: Int?
        public let usageLimit: Double?
        public let usedUnits: Double?
        public let usedPercent: Double?
        public let resetsAt: String?
        public let resetFromNow: String?

        enum CodingKeys: String, CodingKey {
            case windowSizeInHours = "window_size_in_hours"
            case windowSizeInDays = "window_size_in_days"
            case usageLimit = "usage_limit"
            case usedUnits = "used_units"
            case usedPercent = "used_percent"
            case resetsAt = "resets_at"
            case resetFromNow = "reset_from_now"
        }
    }
}
