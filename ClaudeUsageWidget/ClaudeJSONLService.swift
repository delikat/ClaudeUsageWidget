import Foundation
import Shared
import WidgetKit

actor MonthlyFetchState {
    private var lastFetchTime: Date?
    private let debounceInterval: TimeInterval = 10.0

    func shouldFetch() -> Bool {
        let now = Date()
        if let lastFetch = lastFetchTime, now.timeIntervalSince(lastFetch) < debounceInterval {
            return false
        }
        lastFetchTime = now
        return true
    }
}

final class ClaudeJSONLService: Sendable {
    static let shared = ClaudeJSONLService()

    private let fetchState = MonthlyFetchState()
    private let decoder = JSONDecoder()

    private init() {}

    func fetchAndCache() async {
        guard await fetchState.shouldFetch() else {
            print("ClaudeJSONLService: Skipping fetch due to debounce")
            return
        }

        do {
            let cached = try await Task.detached(priority: .userInitiated) {
                try await self.aggregateMonthlyUsage()
            }.value
            try MonthlyUsageCacheManager.claude.write(cached)
            await MainActor.run {
                WidgetCenter.shared.reloadAllTimelines()
            }
            print("ClaudeJSONLService: Successfully cached monthly usage")
        } catch {
            print("ClaudeJSONLService: Failed to parse monthly usage: \(error)")
            let cached = CachedMonthlyUsage(months: [], fetchedAt: Date(), error: .readError)
            try? MonthlyUsageCacheManager.claude.write(cached)
            await MainActor.run {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    private func aggregateMonthlyUsage() async throws -> CachedMonthlyUsage {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let root = homeDir.appendingPathComponent(".claude/projects")

        guard FileManager.default.fileExists(atPath: root.path) else {
            return CachedMonthlyUsage(months: [], fetchedAt: Date(), error: .noData)
        }

        let calendar = Calendar.current
        let currentMonth = MonthlyStats.monthIdentifier(for: Date(), calendar: calendar)
        let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let previousMonth = MonthlyStats.monthIdentifier(for: previousMonthDate, calendar: calendar)
        let allowedMonths: Set<String> = [currentMonth, previousMonth]

        var samples: [MonthlyUsageSample] = []
        var hadReadError = false

        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        if let enumerator {
            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "jsonl" else { continue }
                do {
                    let fileSamples = try await parseFile(fileURL: fileURL, allowedMonths: allowedMonths)
                    samples.append(contentsOf: fileSamples)
                } catch {
                    hadReadError = true
                    print("ClaudeJSONLService: Failed to parse \(fileURL.lastPathComponent): \(error)")
                }
            }
        }

        let stats = MonthlyStatsAggregator.aggregate(samples: samples)
        if stats.isEmpty {
            return CachedMonthlyUsage(months: [], fetchedAt: Date(), error: .noData)
        }

        return CachedMonthlyUsage(months: stats, fetchedAt: Date(), error: hadReadError ? .readError : nil)
    }

    private func parseFile(fileURL: URL, allowedMonths: Set<String>) async throws -> [MonthlyUsageSample] {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        var samples: [MonthlyUsageSample] = []
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for try await line in handle.bytes.lines {
            guard !line.isEmpty, let data = line.data(using: .utf8) else { continue }
            guard let entry = try? decoder.decode(ClaudeLogEntry.self, from: data) else { continue }
            guard let usage = entry.message?.usage else { continue }
            guard let model = entry.message?.model ?? entry.model else { continue }
            guard let timestamp = entry.timestamp,
                  let date = formatter.date(from: timestamp) ?? ISO8601DateFormatter().date(from: timestamp) else {
                continue
            }

            let month = MonthlyStats.monthIdentifier(for: date)
            guard allowedMonths.contains(month) else { continue }

            let inputTokens = usage.inputTokens ?? 0
            let outputTokens = usage.outputTokens ?? 0
            let cacheCreationTokens = usage.cacheCreationInputTokens ?? 0
            let cacheReadTokens = usage.cacheReadInputTokens ?? 0
            let cost = ClaudeModelPricing.calculateCost(
                model: model,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cacheCreationInputTokens: cacheCreationTokens,
                cacheReadInputTokens: cacheReadTokens
            )

            samples.append(
                MonthlyUsageSample(
                    month: month,
                    model: model,
                    inputTokens: inputTokens,
                    outputTokens: outputTokens,
                    cacheCreationInputTokens: cacheCreationTokens,
                    cacheReadInputTokens: cacheReadTokens,
                    costUSD: cost
                )
            )
        }

        return samples
    }
}

private struct ClaudeLogEntry: Decodable {
    let type: String?
    let timestamp: String?
    let message: ClaudeLogMessage?
    let model: String?
}

private struct ClaudeLogMessage: Decodable {
    let model: String?
    let usage: ClaudeLogUsage?
}

private struct ClaudeLogUsage: Decodable {
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheCreationInputTokens: Int?
    let cacheReadInputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
    }
}
