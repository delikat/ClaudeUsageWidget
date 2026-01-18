import Foundation
import Shared
import WidgetKit

/// Service that extracts Claude Code credentials and fetches usage data
@MainActor
final class UsageService {
    static let shared = UsageService()

    private let apiURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private let keychainService = "Claude Code-credentials"

    private init() {}

    /// Fetch usage data and write to cache
    func fetchAndCache() async {
        do {
            let token = try extractToken()
            let usage = try await fetchUsage(token: token)
            let cached = CachedUsage(
                fiveHourUsage: usage.fiveHour.utilization,  // API returns percentage directly
                fiveHourResetAt: parseISO8601Date(usage.fiveHour.resetsAt),
                sevenDayUsage: usage.sevenDay.utilization,  // API returns percentage directly
                sevenDayResetAt: parseISO8601Date(usage.sevenDay.resetsAt),
                fetchedAt: Date(),
                error: nil
            )
            try UsageCacheManager.shared.write(cached)
            WidgetCenter.shared.reloadAllTimelines()
            print("UsageService: Successfully fetched and cached usage data")
        } catch let error as UsageError {
            print("UsageService: Error: \(error)")
            let cached = CachedUsage(
                fiveHourUsage: 0,
                fiveHourResetAt: nil,
                sevenDayUsage: 0,
                sevenDayResetAt: nil,
                fetchedAt: Date(),
                error: mapError(error)
            )
            try? UsageCacheManager.shared.write(cached)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("UsageService: Unexpected error: \(error)")
        }
    }

    /// Extract OAuth token from Claude Code keychain entry
    private func extractToken() throws -> String {
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

        let credentials = try JSONDecoder().decode(ClaudeCredentials.self, from: jsonData)
        return credentials.claudeAiOauth.accessToken
    }

    /// Fetch usage data from Anthropic API
    private func fetchUsage(token: String) async throws -> APIUsageResponse {
        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UsageError.networkError
        }

        switch httpResponse.statusCode {
        case 200:
            return try JSONDecoder().decode(APIUsageResponse.self, from: data)
        case 401:
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
        case .apiError, .invalidCredentialsFormat:
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
