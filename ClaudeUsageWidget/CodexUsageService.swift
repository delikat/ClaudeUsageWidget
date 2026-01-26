import Foundation
import Shared
import WidgetKit

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

final class CodexUsageService: Sendable {
    static let shared = CodexUsageService()

    private let apiUsageURL = URL(string: "https://api.openai.com/v1/organization/usage/completions")!
    private let subscriptionUsageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    private let fetchState = CodexFetchState()

    private let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    private init() {}

    func fetchAndCache() async {
        guard await fetchState.shouldFetch() else {
            print("CodexUsageService: Skipping fetch due to debounce")
            return
        }

        do {
            let settings = CodexSettingsStore.shared
            let cache: CodexCachedUsage

            switch settings.authMethod {
            case .apiKey:
                let apiKey = try readAPIKey()
                let now = Date()
                let fiveHoursAgo = now.addingTimeInterval(-5 * 60 * 60)
                let sevenDaysAgo = now.addingTimeInterval(-7 * 24 * 60 * 60)
                let models = parseCSV(settings.modelFilter)
                let projects = parseCSV(settings.projectFilter)

                async let primaryWindow = fetchUsageWindow(
                    start: fiveHoursAgo,
                    end: now,
                    bucketWidth: "1h",
                    limit: 5,
                    apiKey: apiKey,
                    models: models,
                    projects: projects
                )

                async let secondaryWindow = fetchUsageWindow(
                    start: sevenDaysAgo,
                    end: now,
                    bucketWidth: "1d",
                    limit: 7,
                    apiKey: apiKey,
                    models: models,
                    projects: projects
                )

                let (primary, secondary) = try await (primaryWindow, secondaryWindow)
                cache = CodexCachedUsage(
                    primaryWindow: primary,
                    secondaryWindow: secondary,
                    fetchedAt: now,
                    error: nil,
                    planTitle: "API Key"
                )

            case .chatgptSession:
                guard settings.enableExperimentalSubscription else {
                    throw CodexUsageError.unsupported
                }
                let sessionToken = try readSessionToken()
                let response = try await fetchSubscriptionUsage(token: sessionToken, authMode: settings.subscriptionAuthMode)
                let primary = mapSubscriptionWindow(response.rateLimit?.primaryWindow)
                let secondary = mapSubscriptionWindow(response.rateLimit?.secondaryWindow)
                if primary.usedPercent == nil && secondary.usedPercent == nil {
                    throw CodexUsageError.invalidResponse
                }
                cache = CodexCachedUsage(
                    primaryWindow: primary,
                    secondaryWindow: secondary,
                    fetchedAt: Date(),
                    error: nil,
                    planTitle: response.planType?.capitalized
                )
            }

            try CodexUsageCacheManager.shared.write(cache)
            await MainActor.run {
                WidgetCenter.shared.reloadAllTimelines()
            }
            print("CodexUsageService: Successfully fetched and cached usage data")
        } catch let error as CodexUsageError {
            print("CodexUsageService: Error: \(error)")
            let cached = CodexCachedUsage(
                primaryWindow: CodexUsageWindow(),
                secondaryWindow: CodexUsageWindow(),
                fetchedAt: Date(),
                error: mapError(error),
                planTitle: nil
            )
            try? CodexUsageCacheManager.shared.write(cached)
            await MainActor.run {
                WidgetCenter.shared.reloadAllTimelines()
            }
        } catch let error as URLError {
            print("CodexUsageService: Network error: \(error)")
            let cached = CodexCachedUsage(
                primaryWindow: CodexUsageWindow(),
                secondaryWindow: CodexUsageWindow(),
                fetchedAt: Date(),
                error: .networkError,
                planTitle: nil
            )
            try? CodexUsageCacheManager.shared.write(cached)
            await MainActor.run {
                WidgetCenter.shared.reloadAllTimelines()
            }
        } catch is DecodingError {
            print("CodexUsageService: Decoding error")
            let cached = CodexCachedUsage(
                primaryWindow: CodexUsageWindow(),
                secondaryWindow: CodexUsageWindow(),
                fetchedAt: Date(),
                error: .invalidResponse,
                planTitle: nil
            )
            try? CodexUsageCacheManager.shared.write(cached)
            await MainActor.run {
                WidgetCenter.shared.reloadAllTimelines()
            }
        } catch {
            print("CodexUsageService: Unexpected error: \(error)")
            let cached = CodexCachedUsage(
                primaryWindow: CodexUsageWindow(),
                secondaryWindow: CodexUsageWindow(),
                fetchedAt: Date(),
                error: .apiError,
                planTitle: nil
            )
            try? CodexUsageCacheManager.shared.write(cached)
            await MainActor.run {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    private func readAPIKey() throws -> String {
        if let apiKey = try KeychainStore.shared.readPassword(service: CodexKeychain.service, account: CodexKeychain.apiKeyAccount), !apiKey.isEmpty {
            return apiKey
        }
        throw CodexUsageError.noCredentials
    }

    private func readSessionToken() throws -> String {
        if let token = try KeychainStore.shared.readPassword(service: CodexKeychain.service, account: CodexKeychain.sessionTokenAccount), !token.isEmpty {
            return token
        }
        throw CodexUsageError.noCredentials
    }

    private func fetchUsageWindow(
        start: Date,
        end: Date,
        bucketWidth: String,
        limit: Int,
        apiKey: String,
        models: [String],
        projects: [String]
    ) async throws -> CodexUsageWindow {
        var components = URLComponents(url: apiUsageURL, resolvingAgainstBaseURL: false)
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "start_time", value: String(Int(start.timeIntervalSince1970))),
            URLQueryItem(name: "end_time", value: String(Int(end.timeIntervalSince1970))),
            URLQueryItem(name: "bucket_width", value: bucketWidth),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        for model in models {
            queryItems.append(URLQueryItem(name: "models", value: model))
        }

        for project in projects {
            queryItems.append(URLQueryItem(name: "project_ids", value: project))
        }

        components?.queryItems = queryItems
        guard let url = components?.url else {
            throw CodexUsageError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("ClaudeUsageWidget/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CodexUsageError.networkError
        }

        switch httpResponse.statusCode {
        case 200:
            let buckets = try decodeUsageBuckets(from: data)
            let totals = buckets.reduce(into: (tokens: 0, requests: 0)) { totals, bucket in
                for result in bucket.results {
                    let input = result.inputTokens ?? 0
                    let output = result.outputTokens ?? 0
                    totals.tokens += input + output
                    totals.requests += result.numModelRequests ?? 0
                }
            }
            return CodexUsageWindow(
                tokens: totals.tokens,
                requests: totals.requests,
                windowStart: start,
                windowEnd: end
            )
        case 401, 403:
            throw CodexUsageError.invalidCredentials
        default:
            print("CodexUsageService: API returned status \(httpResponse.statusCode)")
            throw CodexUsageError.apiError
        }
    }

    private func decodeUsageBuckets(from data: Data) throws -> [OpenAIUsageBucket] {
        let decoder = JSONDecoder()
        if let page = try? decoder.decode(OpenAIUsagePage.self, from: data) {
            return page.data
        }
        if let buckets = try? decoder.decode([OpenAIUsageBucket].self, from: data) {
            return buckets
        }
        throw CodexUsageError.invalidResponse
    }

    private func fetchSubscriptionUsage(token: String, authMode: CodexSubscriptionAuthMode) async throws -> CodexSubscriptionUsageResponse {
        var request = URLRequest(url: subscriptionUsageURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("ClaudeUsageWidget/1.0", forHTTPHeaderField: "User-Agent")

        switch authMode {
        case .cookie:
            let cookieValue = token.contains("=") ? token : "__Secure-next-auth.session-token=\(token)"
            request.setValue(cookieValue, forHTTPHeaderField: "Cookie")
        case .bearer:
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CodexUsageError.networkError
        }

        switch httpResponse.statusCode {
        case 200:
            return try JSONDecoder().decode(CodexSubscriptionUsageResponse.self, from: data)
        case 401, 403:
            throw CodexUsageError.invalidCredentials
        default:
            print("CodexUsageService: Subscription API returned status \(httpResponse.statusCode)")
            throw CodexUsageError.apiError
        }
    }

    private func mapSubscriptionWindow(_ window: CodexSubscriptionUsageResponse.RateLimitWindow?) -> CodexUsageWindow {
        guard let window else {
            return CodexUsageWindow()
        }

        let percent: Double?
        if let used = window.usedUnits, let limit = window.usageLimit, limit > 0 {
            percent = min(max((used / limit) * 100, 0), 100)
        } else {
            percent = window.usedPercent
        }

        return CodexUsageWindow(
            usedPercent: percent,
            resetsAt: parseISO8601Date(window.resetsAt)
        )
    }

    private func parseISO8601Date(_ string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    private func parseCSV(_ value: String) -> [String] {
        value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func mapError(_ error: CodexUsageError) -> CodexCachedUsage.CacheError {
        switch error {
        case .noCredentials:
            return .noCredentials
        case .invalidCredentials:
            return .invalidCredentials
        case .networkError:
            return .networkError
        case .invalidResponse:
            return .invalidResponse
        case .unsupported:
            return .unsupported
        case .apiError:
            return .apiError
        }
    }
}

enum CodexUsageError: Error {
    case noCredentials
    case invalidCredentials
    case networkError
    case apiError
    case invalidResponse
    case unsupported
}
