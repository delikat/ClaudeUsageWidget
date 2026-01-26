import Foundation
import Shared
import WidgetKit

/// Actor to track fetch state for debouncing
private actor CodexFetchState {
    private var lastFetchTime: Date?
    private let debounceInterval: TimeInterval = 5.0

    func shouldFetch() -> Bool {
        let now = Date()
        if let lastFetch = lastFetchTime, now.timeIntervalSince(lastFetch) < debounceInterval {
            return false
        }
        lastFetchTime = now
        return true
    }
}

/// Service that extracts Codex credentials and fetches usage data
final class CodexUsageService: Sendable {
    static let shared = CodexUsageService()

    private let apiURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    private let fetchState = CodexFetchState()
    private let userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    /// Configured URLSession with timeout
    private let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    private init() {}

    /// Fetch usage data and write to cache
    func fetchAndCache() async {
        // Check debouncing
        guard await fetchState.shouldFetch() else {
            print("CodexUsageService: Skipping fetch due to debounce (within 5 seconds of last fetch)")
            return
        }

        do {
            // Load credentials from ~/.codex/auth.json
            let credentials = try await Task.detached(priority: .userInitiated) {
                try CodexCredentials.load()
            }.value

            guard let tokens = credentials.tokens else {
                throw CodexUsageError.missingTokens
            }

            let usage = try await fetchUsage(tokens: tokens)
            let cached = CachedUsage(
                fiveHourUsage: Double(usage.rateLimit.primaryWindow.usedPercent),
                fiveHourResetAt: Date(timeIntervalSince1970: Double(usage.rateLimit.primaryWindow.resetAt)),
                sevenDayUsage: Double(usage.rateLimit.secondaryWindow.usedPercent),
                sevenDayResetAt: Date(timeIntervalSince1970: Double(usage.rateLimit.secondaryWindow.resetAt)),
                fetchedAt: Date(),
                error: nil,
                planTitle: formatPlanType(usage.planType)
            )
            try UsageCacheManager.codex.write(cached)
            await MainActor.run {
                WidgetCenter.shared.reloadAllTimelines()
            }
            print("CodexUsageService: Successfully fetched and cached usage data")
        } catch let error as CodexUsageError {
            print("CodexUsageService: Error: \(error)")
            let cached = CachedUsage(
                fiveHourUsage: 0,
                fiveHourResetAt: nil,
                sevenDayUsage: 0,
                sevenDayResetAt: nil,
                fetchedAt: Date(),
                error: mapError(error),
                planTitle: nil
            )
            try? UsageCacheManager.codex.write(cached)
            await MainActor.run {
                WidgetCenter.shared.reloadAllTimelines()
            }
        } catch let error as CodexCredentialsError {
            print("CodexUsageService: Credentials error: \(error)")
            let cached = CachedUsage(
                fiveHourUsage: 0,
                fiveHourResetAt: nil,
                sevenDayUsage: 0,
                sevenDayResetAt: nil,
                fetchedAt: Date(),
                error: error == .fileNotFound ? .noCredentials : .invalidCredentialsFormat,
                planTitle: nil
            )
            try? UsageCacheManager.codex.write(cached)
            await MainActor.run {
                WidgetCenter.shared.reloadAllTimelines()
            }
        } catch let error as URLError {
            print("CodexUsageService: Network error: \(error)")
            let cached = CachedUsage(
                fiveHourUsage: 0,
                fiveHourResetAt: nil,
                sevenDayUsage: 0,
                sevenDayResetAt: nil,
                fetchedAt: Date(),
                error: .networkError,
                planTitle: nil
            )
            try? UsageCacheManager.codex.write(cached)
            await MainActor.run {
                WidgetCenter.shared.reloadAllTimelines()
            }
        } catch is DecodingError {
            print("CodexUsageService: Decoding error - invalid API response format")
            let cached = CachedUsage(
                fiveHourUsage: 0,
                fiveHourResetAt: nil,
                sevenDayUsage: 0,
                sevenDayResetAt: nil,
                fetchedAt: Date(),
                error: .apiError,
                planTitle: nil
            )
            try? UsageCacheManager.codex.write(cached)
            await MainActor.run {
                WidgetCenter.shared.reloadAllTimelines()
            }
        } catch {
            print("CodexUsageService: Unexpected error: \(error)")
            let cached = CachedUsage(
                fiveHourUsage: 0,
                fiveHourResetAt: nil,
                sevenDayUsage: 0,
                sevenDayResetAt: nil,
                fetchedAt: Date(),
                error: .apiError,
                planTitle: nil
            )
            try? UsageCacheManager.codex.write(cached)
            await MainActor.run {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    /// Fetch usage data from Codex API
    private func fetchUsage(tokens: CodexCredentials.CodexTokens) async throws -> CodexUsageResponse {
        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(tokens.accountId, forHTTPHeaderField: "chatgpt-account-id")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CodexUsageError.networkError
        }

        switch httpResponse.statusCode {
        case 200:
            return try JSONDecoder().decode(CodexUsageResponse.self, from: data)
        case 401:
            throw CodexUsageError.invalidToken
        default:
            print("CodexUsageService: API returned status \(httpResponse.statusCode)")
            throw CodexUsageError.apiError
        }
    }

    /// Format plan type for display (e.g., "pro" → "Pro", "plus" → "Plus")
    private func formatPlanType(_ planType: String) -> String {
        planType.capitalized
    }

    /// Map internal errors to cache error types
    private func mapError(_ error: CodexUsageError) -> CachedUsage.CacheError {
        switch error {
        case .noCredentials, .missingTokens:
            return .noCredentials
        case .invalidToken:
            return .invalidToken
        case .networkError:
            return .networkError
        case .apiError:
            return .apiError
        }
    }
}

/// Internal errors for Codex usage fetching
enum CodexUsageError: Error {
    case noCredentials
    case missingTokens
    case invalidToken
    case networkError
    case apiError
}
