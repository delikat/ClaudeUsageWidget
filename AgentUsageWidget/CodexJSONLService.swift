import Foundation
import Shared
import WidgetKit

final class CodexJSONLService: Sendable {
    static let shared = CodexJSONLService()

    private let fetchState = MonthlyFetchState()

    private init() {}

    func fetchAndCache() async {
        guard await fetchState.shouldFetch() else {
            AppLog.usage.debug("CodexJSONLService: Skipping fetch due to debounce")
            return
        }

        do {
            let cached = try await Task.detached(priority: .userInitiated) {
                try await self.aggregateMonthlyUsage()
            }.value
            try MonthlyUsageCacheManager.codex.write(cached)
            await MainActor.run {
                WidgetCenter.shared.reloadAllTimelines()
            }
            AppLog.usage.info("CodexJSONLService: Successfully cached monthly usage")
        } catch {
            AppLog.usage.error("CodexJSONLService: Failed to parse monthly usage: \(error.localizedDescription)")
            let cached = CachedMonthlyUsage(months: [], fetchedAt: Date(), error: .readError)
            try? MonthlyUsageCacheManager.codex.write(cached)
            await MainActor.run {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    private func aggregateMonthlyUsage() async throws -> CachedMonthlyUsage {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let root = homeDir.appendingPathComponent(".codex/sessions")

        guard FileManager.default.fileExists(atPath: root.path) else {
            return CachedMonthlyUsage(months: [], fetchedAt: Date(), error: .noData)
        }

        let calendar = Calendar.current
        let currentMonth = MonthlyStats.monthIdentifier(for: Date(), calendar: calendar)
        let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let previousMonth = MonthlyStats.monthIdentifier(for: previousMonthDate, calendar: calendar)
        let allowedMonths: Set<String> = [currentMonth, previousMonth]

        var samples: [MonthlyUsageSample] = []
        var seenRequestIds: Set<String> = []
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
                    let fileSamples = try await parseFile(
                        fileURL: fileURL,
                        allowedMonths: allowedMonths,
                        seenRequestIds: &seenRequestIds
                    )
                    samples.append(contentsOf: fileSamples)
                } catch {
                    hadReadError = true
                    AppLog.usage.error("CodexJSONLService: Failed to parse \(fileURL.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }

        let stats = MonthlyStatsAggregator.aggregate(samples: samples)
        if stats.isEmpty {
            return CachedMonthlyUsage(months: [], fetchedAt: Date(), error: .noData)
        }

        return CachedMonthlyUsage(months: stats, fetchedAt: Date(), error: hadReadError ? .readError : nil)
    }

    private func parseFile(
        fileURL: URL,
        allowedMonths: Set<String>,
        seenRequestIds: inout Set<String>
    ) async throws -> [MonthlyUsageSample] {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        var parser = CodexSessionParser()

        for try await line in handle.bytes.lines {
            guard !line.isEmpty, let data = line.data(using: .utf8) else { continue }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            parser.processLine(json)
        }

        guard parser.hasUsage, let date = parser.latestTimestamp else {
            return []
        }

        let month = MonthlyStats.monthIdentifier(for: date)
        guard allowedMonths.contains(month) else { return [] }

        // Deduplicate by session ID (fall back to filename)
        let dedupeKey = parser.sessionId ?? fileURL.deletingPathExtension().lastPathComponent
        guard !seenRequestIds.contains(dedupeKey) else { return [] }
        seenRequestIds.insert(dedupeKey)

        let resolvedModel = parser.model ?? "unknown"
        // Codex input_tokens includes cached as a subset, so split them
        // to avoid billing cached tokens at both full and cache-read rates.
        let nonCachedInput = max(parser.totalInput - parser.totalCached, 0)
        let cost = parser.model == nil ? 0 : CodexModelPricing.calculateCost(
            model: resolvedModel,
            inputTokens: nonCachedInput,
            outputTokens: parser.totalOutput,
            cacheCreationInputTokens: 0,
            cacheReadInputTokens: parser.totalCached
        )

        let sample = MonthlyUsageSample(
            month: month,
            model: resolvedModel,
            inputTokens: parser.totalInput,
            outputTokens: parser.totalOutput,
            cacheCreationInputTokens: 0,
            cacheReadInputTokens: parser.totalCached,
            costUSD: cost
        )
        return [sample]
    }
}
