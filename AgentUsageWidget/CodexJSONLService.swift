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

        var samples: [MonthlyUsageSample] = []

        for try await line in handle.bytes.lines {
            guard !line.isEmpty, let data = line.data(using: .utf8) else { continue }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

            let sample = parseSample(from: json, allowedMonths: allowedMonths)
            let dedupeKey = JSONLDedupe.extractDedupeKey(from: json)
            guard let accepted = JSONLDedupe.acceptSample(
                sample,
                dedupeKey: dedupeKey,
                seenKeys: &seenRequestIds
            ) else { continue }
            samples.append(accepted)
        }

        return samples
    }

    private func parseSample(from json: [String: Any], allowedMonths: Set<String>) -> MonthlyUsageSample? {
        guard let date = extractTimestamp(from: json) else { return nil }
        let month = MonthlyStats.monthIdentifier(for: date)
        guard allowedMonths.contains(month) else { return nil }

        let model = extractModel(from: json) ?? "unknown"
        let usage = extractUsage(from: json)

        let inputTokens = usage?.inputTokens ?? 0
        let outputTokens = usage?.outputTokens ?? 0
        let cacheCreationTokens = usage?.cacheCreationInputTokens ?? 0
        let cacheReadTokens = usage?.cacheReadInputTokens ?? 0
        let cost = extractCost(from: json) ?? 0

        return MonthlyUsageSample(
            month: month,
            model: model,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationInputTokens: cacheCreationTokens,
            cacheReadInputTokens: cacheReadTokens,
            costUSD: cost
        )
    }

    private func extractUsage(from json: [String: Any]) -> CodexUsageTokens? {
        let candidates = [
            json["usage"] as? [String: Any],
            (json["response"] as? [String: Any])?["usage"] as? [String: Any],
            (json["message"] as? [String: Any])?["usage"] as? [String: Any]
        ].compactMap { $0 }

        for usage in candidates {
            let input = intValue(from: usage["input_tokens"])
                ?? intValue(from: usage["prompt_tokens"])
                ?? intValue(from: usage["inputTokens"])
            let output = intValue(from: usage["output_tokens"])
                ?? intValue(from: usage["completion_tokens"])
                ?? intValue(from: usage["outputTokens"])
            let cacheCreation = intValue(from: usage["cache_creation_input_tokens"])
                ?? intValue(from: usage["cacheCreationInputTokens"])
            let cacheRead = intValue(from: usage["cache_read_input_tokens"])
                ?? intValue(from: usage["cacheReadInputTokens"])

            if input != nil || output != nil || cacheCreation != nil || cacheRead != nil {
                return CodexUsageTokens(
                    inputTokens: input ?? 0,
                    outputTokens: output ?? 0,
                    cacheCreationInputTokens: cacheCreation ?? 0,
                    cacheReadInputTokens: cacheRead ?? 0
                )
            }
        }

        return nil
    }

    private func extractTimestamp(from json: [String: Any]) -> Date? {
        let candidates: [Any?] = [
            json["timestamp"],
            json["created_at"],
            json["created"],
            json["time"],
            (json["response"] as? [String: Any])?["created_at"],
            (json["response"] as? [String: Any])?["created"],
            (json["message"] as? [String: Any])?["timestamp"]
        ]

        for candidate in candidates {
            if let date = parseDate(candidate) {
                return date
            }
        }

        return nil
    }

    private func extractModel(from json: [String: Any]) -> String? {
        if let model = json["model"] as? String { return model }
        if let model = (json["request"] as? [String: Any])?["model"] as? String { return model }
        if let model = (json["response"] as? [String: Any])?["model"] as? String { return model }
        if let model = (json["message"] as? [String: Any])?["model"] as? String { return model }
        return nil
    }

    private func extractCost(from json: [String: Any]) -> Double? {
        let candidates: [Any?] = [
            json["cost"],
            json["cost_usd"],
            json["costUSD"],
            json["usd_cost"],
            (json["response"] as? [String: Any])?["cost"],
            (json["response"] as? [String: Any])?["cost_usd"]
        ]
        for candidate in candidates {
            if let value = doubleValue(from: candidate) {
                return value
            }
        }
        return nil
    }

    private func parseDate(_ value: Any?) -> Date? {
        if let string = value as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: string) {
                return date
            }
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: string)
        }
        if let number = doubleValue(from: value) {
            let timestamp = number > 2_000_000_000_000 ? number / 1000.0 : number
            return Date(timeIntervalSince1970: timestamp)
        }
        return nil
    }

    private func intValue(from value: Any?) -> Int? {
        if let intValue = value as? Int { return intValue }
        if let doubleValue = value as? Double { return Int(doubleValue) }
        if let stringValue = value as? String, let intValue = Int(stringValue) { return intValue }
        return nil
    }

    private func doubleValue(from value: Any?) -> Double? {
        if let doubleValue = value as? Double { return doubleValue }
        if let intValue = value as? Int { return Double(intValue) }
        if let stringValue = value as? String, let doubleValue = Double(stringValue) { return doubleValue }
        return nil
    }
}

private struct CodexUsageTokens {
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationInputTokens: Int
    let cacheReadInputTokens: Int
}
