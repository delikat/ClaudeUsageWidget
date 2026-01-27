import Foundation
import Shared
import WidgetKit

/// Actor to track fetch state for debouncing
private actor FetchState {
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

/// Service that extracts Claude Code credentials and fetches usage data
final class UsageService: Sendable {
    static let shared = UsageService()

    private let apiURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private let keychainService = "Claude Code-credentials"
    private let fetchState = FetchState()

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
            print("UsageService: Skipping fetch due to debounce (within 5 seconds of last fetch)")
            return
        }

        do {
            // Run extractCredentials on background thread to avoid blocking main thread
            let credentials = try await Task.detached(priority: .userInitiated) {
                try self.extractCredentials()
            }.value

            // Log warning if token appears expired (but still try - Claude Code may have refreshed)
            if isTokenExpired(credentials) {
                print("UsageService: Token appears expired, will attempt fetch anyway (Claude Code may have refreshed)")
            }

            let usage = try await fetchUsage(token: credentials.claudeAiOauth.accessToken)
            let cached = CachedUsage(
                fiveHourUsage: usage.fiveHour.utilization,  // API returns percentage directly
                fiveHourResetAt: parseISO8601Date(usage.fiveHour.resetsAt),
                sevenDayUsage: usage.sevenDay.utilization,  // API returns percentage directly
                sevenDayResetAt: parseISO8601Date(usage.sevenDay.resetsAt),
                fetchedAt: Date(),
                error: nil,
                planTitle: credentials.claudeAiOauth.displayTier.map { "Claude \($0)" }
            )
            try UsageCacheManager.shared.write(cached)
            await MainActor.run {
                WidgetCenter.shared.reloadAllTimelines()
            }
            print("UsageService: Successfully fetched and cached usage data")
        } catch let error as UsageError {
            print("UsageService: Error: \(error)")
            let cached = CachedUsage(
                fiveHourUsage: 0,
                fiveHourResetAt: nil,
                sevenDayUsage: 0,
                sevenDayResetAt: nil,
                fetchedAt: Date(),
                error: mapError(error),
                planTitle: nil
            )
            try? UsageCacheManager.shared.write(cached)
            await MainActor.run {
                WidgetCenter.shared.reloadAllTimelines()
            }
        } catch let error as URLError {
            print("UsageService: Network error: \(error)")
            let cached = CachedUsage(
                fiveHourUsage: 0,
                fiveHourResetAt: nil,
                sevenDayUsage: 0,
                sevenDayResetAt: nil,
                fetchedAt: Date(),
                error: .networkError,
                planTitle: nil
            )
            try? UsageCacheManager.shared.write(cached)
            await MainActor.run {
                WidgetCenter.shared.reloadAllTimelines()
            }
        } catch is DecodingError {
            print("UsageService: Decoding error - invalid credentials format")
            let cached = CachedUsage(
                fiveHourUsage: 0,
                fiveHourResetAt: nil,
                sevenDayUsage: 0,
                sevenDayResetAt: nil,
                fetchedAt: Date(),
                error: .invalidCredentialsFormat,
                planTitle: nil
            )
            try? UsageCacheManager.shared.write(cached)
            await MainActor.run {
                WidgetCenter.shared.reloadAllTimelines()
            }
        } catch {
            print("UsageService: Unexpected error: \(error)")
            // Cache as API error so widget shows something useful
            let cached = CachedUsage(
                fiveHourUsage: 0,
                fiveHourResetAt: nil,
                sevenDayUsage: 0,
                sevenDayResetAt: nil,
                fetchedAt: Date(),
                error: .apiError,
                planTitle: nil
            )
            try? UsageCacheManager.shared.write(cached)
            await MainActor.run {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    /// Extract OAuth credentials from Claude Code keychain entry
    private func extractCredentials() throws -> ClaudeCredentials {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", keychainService, "-w"]

        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw UsageError.keychainAccessFailed
        }

        guard process.terminationStatus == 0 else {
            throw UsageError.noCredentials
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let jsonString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw UsageError.invalidCredentialsFormat
        }

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw UsageError.invalidCredentialsFormat
        }

        return try JSONDecoder().decode(ClaudeCredentials.self, from: jsonData)
    }

    /// Check if the OAuth token is expired
    private func isTokenExpired(_ credentials: ClaudeCredentials) -> Bool {
        guard let expiresAt = credentials.claudeAiOauth.expiresAt else {
            return false  // No expiry info = assume valid
        }
        let expiryDate = Date(timeIntervalSince1970: Double(expiresAt) / 1000.0)
        return Date() > expiryDate
    }

    /// Fetch usage data from Anthropic API with optional retry on 401
    private func fetchUsage(token: String, retryCount: Int = 0) async throws -> APIUsageResponse {
        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UsageError.networkError
        }

        switch httpResponse.statusCode {
        case 200:
            return try JSONDecoder().decode(APIUsageResponse.self, from: data)
        case 401:
            // On first 401, re-read keychain in case Claude Code refreshed the token
            if retryCount == 0 {
                print("UsageService: Got 401, re-reading keychain for potentially refreshed token")
                let freshCredentials = try await Task.detached(priority: .userInitiated) {
                    try self.extractCredentials()
                }.value
                return try await fetchUsage(token: freshCredentials.claudeAiOauth.accessToken, retryCount: 1)
            }
            throw UsageError.invalidToken
        default:
            print("UsageService: API returned status \(httpResponse.statusCode)")
            throw UsageError.apiError
        }
    }

    /// Parse ISO8601 date string
    private func parseISO8601Date(_ string: String?) -> Date? {
        guard let string = string else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            return date
        }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    /// Map internal errors to cache error types
    private func mapError(_ error: UsageError) -> CachedUsage.CacheError {
        switch error {
        case .noCredentials, .keychainAccessFailed:
            return .noCredentials
        case .invalidToken:
            return .invalidToken
        case .networkError:
            return .networkError
        case .invalidCredentialsFormat:
            return .invalidCredentialsFormat
        case .apiError:
            return .apiError
        }
    }
}

/// Internal errors for usage fetching
enum UsageError: Error {
    case noCredentials
    case keychainAccessFailed
    case invalidCredentialsFormat
    case invalidToken
    case networkError
    case apiError
}
