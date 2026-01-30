import Foundation

/// Parser for Claude and Codex JSONL conversation logs
public struct JSONLParser {

    /// Parsed conversation entry with timestamp and estimated tokens
    public struct ConversationEntry: Sendable {
        public let timestamp: Date
        public let estimatedTokens: Int
        public let provider: Provider

        public enum Provider: String, Sendable {
            case claude
            case codex
        }
    }

    /// Parse JSONL files from Claude conversation logs
    /// Path pattern: ~/.claude/projects/**/*.jsonl
    public static func parseClaudeLogs() -> [ConversationEntry] {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let claudeProjectsDir = homeDir.appendingPathComponent(".claude/projects")

        guard FileManager.default.fileExists(atPath: claudeProjectsDir.path) else {
            AppLog.jsonl.info("JSONLParser: Claude projects directory not found at \(claudeProjectsDir.path)")
            return []
        }

        let jsonlFiles = findJSONLFiles(in: claudeProjectsDir)
        AppLog.jsonl.debug("JSONLParser: Found \(jsonlFiles.count) Claude JSONL files")

        var entries: [ConversationEntry] = []
        for file in jsonlFiles {
            entries.append(contentsOf: parseClaudeJSONLFile(at: file))
        }

        return entries
    }

    /// Parse JSONL files from Codex session logs
    /// Path pattern: ~/.codex/sessions/**/*.jsonl
    public static func parseCodexLogs() -> [ConversationEntry] {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let codexSessionsDir = homeDir.appendingPathComponent(".codex/sessions")

        guard FileManager.default.fileExists(atPath: codexSessionsDir.path) else {
            AppLog.jsonl.info("JSONLParser: Codex sessions directory not found at \(codexSessionsDir.path)")
            return []
        }

        let jsonlFiles = findJSONLFiles(in: codexSessionsDir)
        AppLog.jsonl.debug("JSONLParser: Found \(jsonlFiles.count) Codex JSONL files")

        var entries: [ConversationEntry] = []
        for file in jsonlFiles {
            entries.append(contentsOf: parseCodexJSONLFile(at: file))
        }

        return entries
    }

    /// Find all .jsonl files recursively in a directory
    private static func findJSONLFiles(in directory: URL) -> [URL] {
        var jsonlFiles: [URL] = []

        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "jsonl" {
                jsonlFiles.append(fileURL)
            }
        }

        return jsonlFiles
    }

    /// Parse a Claude JSONL file
    /// Claude format: {"type":"user"|"assistant","message":{...},"timestamp":"2025-06-02T18:46:59.937Z"}
    private static func parseClaudeJSONLFile(at url: URL) -> [ConversationEntry] {
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else {
            return []
        }

        var entries: [ConversationEntry] = []
        let lines = content.components(separatedBy: .newlines)

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]

        for line in lines where !line.isEmpty {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let timestampStr = json["timestamp"] as? String,
                  let timestamp = dateFormatter.date(from: timestampStr) ?? fallbackFormatter.date(from: timestampStr) else {
                continue
            }

            // Estimate tokens from message content
            let tokens = estimateTokensFromClaudeMessage(json)
            if tokens > 0 {
                entries.append(ConversationEntry(timestamp: timestamp, estimatedTokens: tokens, provider: .claude))
            }
        }

        return entries
    }

    /// Parse a Codex JSONL file by extracting actual token counts from
    /// `event_msg` lines with `payload.type == "token_count"`. If no
    /// token_count events are found, fall back to estimating tokens from
    /// message/content lines with legacy timestamps.
    private static func parseCodexJSONLFile(at url: URL) -> [ConversationEntry] {
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else {
            return []
        }

        var entries: [ConversationEntry] = []
        var fallbackEntries: [ConversationEntry] = []
        let lines = content.components(separatedBy: .newlines)

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]

        var prevTotalInput = 0
        var prevTotalCached = 0
        var prevTotalOutput = 0

        for line in lines where !line.isEmpty {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            guard let eventType = json["type"] as? String, eventType == "event_msg",
                  let payload = json["payload"] as? [String: Any],
                  let payloadType = payload["type"] as? String, payloadType == "token_count" else {
                let fallbackTokens = estimateTokensFromCodexMessage(json)
                guard fallbackTokens > 0,
                      let timestamp = parseCodexTimestamp(
                          json,
                          dateFormatter: dateFormatter,
                          fallbackFormatter: fallbackFormatter
                      ) else {
                    continue
                }
                fallbackEntries.append(
                    ConversationEntry(timestamp: timestamp, estimatedTokens: fallbackTokens, provider: .codex)
                )
                continue
            }

            guard let timestamp = parseCodexTimestamp(
                json,
                dateFormatter: dateFormatter,
                fallbackFormatter: fallbackFormatter
            ) else {
                continue
            }

            let info = payload["info"] as? [String: Any]
            let lastUsage = info?["last_token_usage"] as? [String: Any]
            let cumUsage = info?["total_token_usage"] as? [String: Any]

            var dInput = 0, dCached = 0, dOutput = 0
            if let last = lastUsage {
                dInput = intValueFromAny(last["input_tokens"]) ?? 0
                dCached = intValueFromAny(last["cached_input_tokens"] ?? last["cache_read_input_tokens"]) ?? 0
                dOutput = intValueFromAny(last["output_tokens"]) ?? 0
            } else if let cum = cumUsage {
                let curInput = intValueFromAny(cum["input_tokens"]) ?? 0
                let curCached = intValueFromAny(cum["cached_input_tokens"] ?? cum["cache_read_input_tokens"]) ?? 0
                let curOutput = intValueFromAny(cum["output_tokens"]) ?? 0
                dInput = max(curInput - prevTotalInput, 0)
                dCached = max(curCached - prevTotalCached, 0)
                dOutput = max(curOutput - prevTotalOutput, 0)
            }

            if let cum = cumUsage {
                prevTotalInput = intValueFromAny(cum["input_tokens"]) ?? prevTotalInput
                prevTotalCached = intValueFromAny(cum["cached_input_tokens"] ?? cum["cache_read_input_tokens"]) ?? prevTotalCached
                prevTotalOutput = intValueFromAny(cum["output_tokens"]) ?? prevTotalOutput
            } else {
                prevTotalInput += dInput
                prevTotalCached += dCached
                prevTotalOutput += dOutput
            }

            // cached is a subset of input in Codex, so don't add it again
            let totalTokens = dInput + dOutput
            guard totalTokens > 0 else { continue }

            entries.append(ConversationEntry(timestamp: timestamp, estimatedTokens: totalTokens, provider: .codex))
        }

        return entries.isEmpty ? fallbackEntries : entries
    }

    private static func intValueFromAny(_ value: Any?) -> Int? {
        if let intValue = value as? Int { return intValue }
        if let doubleValue = value as? Double { return Int(doubleValue) }
        if let stringValue = value as? String { return Int(stringValue) }
        return nil
    }

    /// Estimate tokens from Claude message JSON
    private static func estimateTokensFromClaudeMessage(_ json: [String: Any]) -> Int {
        guard let message = json["message"] as? [String: Any] else {
            return 0
        }

        let totalChars = countCharacters(in: message["content"])
        guard totalChars > 0 else { return 0 }

        // Approximate tokens: ~4 characters per token
        return max(1, totalChars / 4)
    }

    private static func estimateTokensFromCodexMessage(_ json: [String: Any]) -> Int {
        var totalChars = 0
        if let message = json["message"] as? [String: Any] {
            totalChars += countCharacters(in: message["content"])
        } else if let content = json["content"] {
            totalChars += countCharacters(in: content)
        } else if let text = json["text"] as? String {
            totalChars += text.count
        }
        if totalChars == 0, let payload = json["payload"] as? [String: Any] {
            if let message = payload["message"] as? [String: Any] {
                totalChars += countCharacters(in: message["content"])
            } else if let content = payload["content"] {
                totalChars += countCharacters(in: content)
            } else if let text = payload["text"] as? String {
                totalChars += text.count
            }
        }

        guard totalChars > 0 else { return 0 }
        return max(1, totalChars / 4)
    }

    private static func countCharacters(in value: Any?) -> Int {
        guard let value else { return 0 }
        if let stringValue = value as? String {
            return stringValue.count
        }
        if let arrayValue = value as? [Any] {
            return arrayValue.reduce(0) { $0 + countCharacters(in: $1) }
        }
        if let dictValue = value as? [String: Any] {
            if let text = dictValue["text"] as? String {
                return text.count
            }
            if let content = dictValue["content"] {
                return countCharacters(in: content)
            }
        }
        return 0
    }

    private static func parseCodexTimestamp(
        _ json: [String: Any],
        dateFormatter: ISO8601DateFormatter,
        fallbackFormatter: ISO8601DateFormatter
    ) -> Date? {
        if let date = parseTimestampValue(
            json["timestamp"],
            dateFormatter: dateFormatter,
            fallbackFormatter: fallbackFormatter
        ) {
            return date
        }
        if let date = parseTimestampValue(
            json["createdAt"],
            dateFormatter: dateFormatter,
            fallbackFormatter: fallbackFormatter
        ) {
            return date
        }
        if let date = parseTimestampValue(
            json["created_at"],
            dateFormatter: dateFormatter,
            fallbackFormatter: fallbackFormatter
        ) {
            return date
        }
        if let message = json["message"] as? [String: Any] {
            if let date = parseTimestampValue(
                message["timestamp"],
                dateFormatter: dateFormatter,
                fallbackFormatter: fallbackFormatter
            ) {
                return date
            }
            if let date = parseTimestampValue(
                message["createdAt"],
                dateFormatter: dateFormatter,
                fallbackFormatter: fallbackFormatter
            ) {
                return date
            }
            if let date = parseTimestampValue(
                message["created_at"],
                dateFormatter: dateFormatter,
                fallbackFormatter: fallbackFormatter
            ) {
                return date
            }
        }
        if let payload = json["payload"] as? [String: Any] {
            if let date = parseTimestampValue(
                payload["timestamp"],
                dateFormatter: dateFormatter,
                fallbackFormatter: fallbackFormatter
            ) {
                return date
            }
            if let date = parseTimestampValue(
                payload["createdAt"],
                dateFormatter: dateFormatter,
                fallbackFormatter: fallbackFormatter
            ) {
                return date
            }
            if let date = parseTimestampValue(
                payload["created_at"],
                dateFormatter: dateFormatter,
                fallbackFormatter: fallbackFormatter
            ) {
                return date
            }
        }
        return nil
    }

    private static func parseTimestampValue(
        _ value: Any?,
        dateFormatter: ISO8601DateFormatter,
        fallbackFormatter: ISO8601DateFormatter
    ) -> Date? {
        if let stringValue = value as? String {
            return dateFormatter.date(from: stringValue) ?? fallbackFormatter.date(from: stringValue)
        }
        if let numberValue = value as? NSNumber {
            return dateFromEpoch(numberValue.doubleValue)
        }
        if let intValue = value as? Int {
            return dateFromEpoch(Double(intValue))
        }
        if let doubleValue = value as? Double {
            return dateFromEpoch(doubleValue)
        }
        return nil
    }

    private static func dateFromEpoch(_ value: Double) -> Date? {
        guard value > 0 else { return nil }
        let seconds = value > 10_000_000_000 ? value / 1000.0 : value
        return Date(timeIntervalSince1970: seconds)
    }

}

/// Aggregator to convert conversation entries into daily usage
public struct UsageAggregator {

    /// Aggregate conversation entries into daily usage data
    public static func aggregate(entries: [JSONLParser.ConversationEntry]) -> [DailyUsage] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        // Group entries by date and provider
        var dailyData: [String: (claude: Int, codex: Int)] = [:]

        for entry in entries {
            let dateKey = dateFormatter.string(from: entry.timestamp)
            var current = dailyData[dateKey] ?? (claude: 0, codex: 0)

            switch entry.provider {
            case .claude:
                current.claude += entry.estimatedTokens
            case .codex:
                current.codex += entry.estimatedTokens
            }

            dailyData[dateKey] = current
        }

        // Convert to DailyUsage array, sorted by date descending
        let sortedDates = dailyData.keys.sorted().reversed()
        return sortedDates.map { date in
            let data = dailyData[date]!
            return DailyUsage(date: date, claudeTokens: data.claude, codexTokens: data.codex)
        }
    }

    /// Merge new aggregated data with existing history, keeping last 90 days
    public static func merge(new: [DailyUsage], existing: UsageHistory) -> UsageHistory {
        var merged: [String: DailyUsage] = [:]

        // Add existing entries
        for entry in existing.entries {
            merged[entry.date] = entry
        }

        // Update/add new entries
        for entry in new {
            merged[entry.date] = entry
        }

        // Sort by date descending and keep last 90 days
        let sorted = merged.values.sorted { $0.date > $1.date }
        let trimmed = Array(sorted.prefix(90))

        return UsageHistory(entries: trimmed)
    }
}
