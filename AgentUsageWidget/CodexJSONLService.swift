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

    /// Parses a single Codex session file.
    ///
    /// Each file contains structured events:
    /// - `session_meta`: has `payload.id` (session ID for dedup)
    /// - `turn_context`: has `payload.model` (e.g. "gpt-5.2-codex")
    /// - `event_msg` with `payload.type == "token_count"`: has
    ///   `payload.info.total_token_usage` (cumulative per-turn) and
    ///   `payload.info.last_token_usage` (per-call delta)
    ///
    /// We sum `last_token_usage` from every token_count event to get
    /// session totals. When `last_token_usage` is absent we compute
    /// the delta from `total_token_usage - previousTotals`.
    /// This matches the approach used by @ccusage/codex.
    private func parseFile(
        fileURL: URL,
        allowedMonths: Set<String>,
        seenRequestIds: inout Set<String>
    ) async throws -> [MonthlyUsageSample] {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var sessionId: String?
        var model: String?
        var latestTimestamp: Date?

        // Running totals for the session
        var totalInput = 0
        var totalCached = 0
        var totalOutput = 0

        // Track previous cumulative totals for delta fallback
        var prevTotalInput = 0
        var prevTotalCached = 0
        var prevTotalOutput = 0

        for try await line in handle.bytes.lines {
            guard !line.isEmpty, let data = line.data(using: .utf8) else { continue }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            guard let payload = json["payload"] as? [String: Any] else { continue }

            let eventType = json["type"] as? String

            if eventType == "session_meta" {
                sessionId = payload["id"] as? String
            }

            if eventType == "turn_context", model == nil {
                model = payload["model"] as? String
            }

            if eventType == "event_msg",
               let payloadType = payload["type"] as? String,
               payloadType == "token_count"
            {
                let info = payload["info"] as? [String: Any]
                let lastUsage = info?["last_token_usage"] as? [String: Any]
                let cumUsage = info?["total_token_usage"] as? [String: Any]

                // Prefer last_token_usage (explicit delta); fall back to
                // computing delta from cumulative totals.
                var dInput = 0, dCached = 0, dOutput = 0
                if let last = lastUsage {
                    dInput = intValue(from: last["input_tokens"]) ?? 0
                    dCached = intValue(from: last["cached_input_tokens"]) ?? 0
                    dOutput = intValue(from: last["output_tokens"]) ?? 0
                } else if let cum = cumUsage {
                    let curInput = intValue(from: cum["input_tokens"]) ?? 0
                    let curCached = intValue(from: cum["cached_input_tokens"]) ?? 0
                    let curOutput = intValue(from: cum["output_tokens"]) ?? 0
                    dInput = max(curInput - prevTotalInput, 0)
                    dCached = max(curCached - prevTotalCached, 0)
                    dOutput = max(curOutput - prevTotalOutput, 0)
                }

                // Update previous cumulative totals
                if let cum = cumUsage {
                    prevTotalInput = intValue(from: cum["input_tokens"]) ?? prevTotalInput
                    prevTotalCached = intValue(from: cum["cached_input_tokens"]) ?? prevTotalCached
                    prevTotalOutput = intValue(from: cum["output_tokens"]) ?? prevTotalOutput
                }

                // Skip zero-delta events
                guard dInput > 0 || dCached > 0 || dOutput > 0 else { continue }

                totalInput += dInput
                totalCached += dCached
                totalOutput += dOutput

                if let ts = json["timestamp"] as? String {
                    latestTimestamp = formatter.date(from: ts)
                }
            }
        }

        guard totalInput > 0 || totalCached > 0 || totalOutput > 0,
              let date = latestTimestamp else {
            return []
        }

        let month = MonthlyStats.monthIdentifier(for: date)
        guard allowedMonths.contains(month) else { return [] }

        // Deduplicate by session ID (fall back to filename)
        let dedupeKey = sessionId ?? fileURL.deletingPathExtension().lastPathComponent
        guard !seenRequestIds.contains(dedupeKey) else { return [] }
        seenRequestIds.insert(dedupeKey)

        let sample = MonthlyUsageSample(
            month: month,
            model: model ?? "unknown",
            inputTokens: totalInput,
            outputTokens: totalOutput,
            cacheCreationInputTokens: 0,
            cacheReadInputTokens: totalCached,
            costUSD: 0
        )
        return [sample]
    }

    private func intValue(from value: Any?) -> Int? {
        if let intValue = value as? Int { return intValue }
        if let doubleValue = value as? Double { return Int(doubleValue) }
        if let stringValue = value as? String, let intValue = Int(stringValue) { return intValue }
        return nil
    }
}
