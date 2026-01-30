import Foundation

/// Accumulates token usage from a Codex session's JSONL events.
///
/// Feed each parsed JSON line via ``processLine(_:)`` then read
/// the accumulated totals. Handles the `session_meta`, `turn_context`,
/// and `token_count` event types produced by Codex CLI.
public struct CodexSessionParser {
    public private(set) var sessionId: String?
    public private(set) var model: String?
    public private(set) var latestTimestamp: Date?

    public private(set) var totalInput = 0
    public private(set) var totalCached = 0
    public private(set) var totalOutput = 0
    public private(set) var totalReasoning = 0
    public private(set) var totalTokens = 0

    private var prevTotalInput = 0
    private var prevTotalCached = 0
    private var prevTotalOutput = 0
    private var prevTotalReasoning = 0
    private var prevTotalTokens = 0

    private let fracFormatter: ISO8601DateFormatter
    private let plainFormatter: ISO8601DateFormatter

    public init() {
        fracFormatter = ISO8601DateFormatter()
        fracFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        plainFormatter = ISO8601DateFormatter()
        plainFormatter.formatOptions = [.withInternetDateTime]
    }

    public var hasUsage: Bool {
        totalInput > 0 || totalCached > 0 || totalOutput > 0
    }

    /// Process a single parsed JSONL line (already deserialized to a dictionary).
    public mutating func processLine(_ json: [String: Any]) {
        guard let payload = json["payload"] as? [String: Any] else { return }
        let eventType = json["type"] as? String

        if eventType == "session_meta" {
            sessionId = payload["id"] as? String
        }

        if eventType == "turn_context" {
            if let contextModel = payload["model"] as? String, !contextModel.isEmpty {
                model = contextModel
            }
        }

        if eventType == "event_msg",
           let payloadType = payload["type"] as? String,
           payloadType == "token_count"
        {
            let info = payload["info"] as? [String: Any]
            let lastUsage = info?["last_token_usage"] as? [String: Any]
            let cumUsage = info?["total_token_usage"] as? [String: Any]

            // Extract model from token_count payload
            if let extractedModel = extractModelFromPayload(payload) {
                model = extractedModel
            }

            // Prefer last_token_usage (explicit delta); fall back to
            // computing delta from cumulative totals.
            var dInput = 0, dCached = 0, dOutput = 0, dReasoning = 0, dTotal = 0
            if let last = lastUsage {
                dInput = intValue(from: last["input_tokens"]) ?? 0
                dCached = intValue(from: last["cached_input_tokens"] ?? last["cache_read_input_tokens"]) ?? 0
                dOutput = intValue(from: last["output_tokens"]) ?? 0
                dReasoning = intValue(from: last["reasoning_output_tokens"]) ?? 0
                let rawTotal = intValue(from: last["total_tokens"]) ?? 0
                dTotal = rawTotal > 0 ? rawTotal : dInput + dOutput
            } else if let cum = cumUsage {
                let curInput = intValue(from: cum["input_tokens"]) ?? 0
                let curCached = intValue(from: cum["cached_input_tokens"] ?? cum["cache_read_input_tokens"]) ?? 0
                let curOutput = intValue(from: cum["output_tokens"]) ?? 0
                let curReasoning = intValue(from: cum["reasoning_output_tokens"]) ?? 0
                let rawCurTotal = intValue(from: cum["total_tokens"]) ?? 0
                let curTotal = rawCurTotal > 0 ? rawCurTotal : curInput + curOutput
                dInput = max(curInput - prevTotalInput, 0)
                dCached = max(curCached - prevTotalCached, 0)
                dOutput = max(curOutput - prevTotalOutput, 0)
                dReasoning = max(curReasoning - prevTotalReasoning, 0)
                dTotal = max(curTotal - prevTotalTokens, 0)
            }

            // Update previous cumulative totals so the delta fallback
            // stays correct even if last/total presence is inconsistent.
            if let cum = cumUsage {
                prevTotalInput = intValue(from: cum["input_tokens"]) ?? prevTotalInput
                prevTotalCached = intValue(from: cum["cached_input_tokens"] ?? cum["cache_read_input_tokens"]) ?? prevTotalCached
                prevTotalOutput = intValue(from: cum["output_tokens"]) ?? prevTotalOutput
                prevTotalReasoning = intValue(from: cum["reasoning_output_tokens"]) ?? prevTotalReasoning
                let rawCumTotal = intValue(from: cum["total_tokens"]) ?? 0
                prevTotalTokens = rawCumTotal > 0 ? rawCumTotal : (prevTotalInput + prevTotalOutput)
            } else {
                prevTotalInput += dInput
                prevTotalCached += dCached
                prevTotalOutput += dOutput
                prevTotalReasoning += dReasoning
                prevTotalTokens += dTotal
            }

            // Skip zero-delta events
            guard dInput > 0 || dCached > 0 || dOutput > 0 || dReasoning > 0 else { return }

            totalInput += dInput
            totalCached += dCached
            totalOutput += dOutput
            totalReasoning += dReasoning
            totalTokens += dTotal

            if let ts = json["timestamp"] as? String,
               let date = fracFormatter.date(from: ts) ?? plainFormatter.date(from: ts)
            {
                latestTimestamp = date
            }
        }
    }

    /// Extract model name from a token_count payload, checking info.model,
    /// info.model_name, info.metadata.model, payload.model, payload.metadata.model.
    private func extractModelFromPayload(_ payload: [String: Any]) -> String? {
        let info = payload["info"] as? [String: Any]

        // Check info.model, info.model_name
        if let info {
            if let m = info["model"] as? String, !m.trimmingCharacters(in: .whitespaces).isEmpty {
                return m.trimmingCharacters(in: .whitespaces)
            }
            if let m = info["model_name"] as? String, !m.trimmingCharacters(in: .whitespaces).isEmpty {
                return m.trimmingCharacters(in: .whitespaces)
            }
            // Check info.metadata.model
            if let metadata = info["metadata"] as? [String: Any],
               let m = metadata["model"] as? String, !m.trimmingCharacters(in: .whitespaces).isEmpty {
                return m.trimmingCharacters(in: .whitespaces)
            }
        }

        // Check payload.model
        if let m = payload["model"] as? String, !m.trimmingCharacters(in: .whitespaces).isEmpty {
            return m.trimmingCharacters(in: .whitespaces)
        }

        // Check payload.metadata.model
        if let metadata = payload["metadata"] as? [String: Any],
           let m = metadata["model"] as? String, !m.trimmingCharacters(in: .whitespaces).isEmpty {
            return m.trimmingCharacters(in: .whitespaces)
        }

        return nil
    }

    private func intValue(from value: Any?) -> Int? {
        if let intValue = value as? Int { return intValue }
        if let doubleValue = value as? Double { return Int(doubleValue) }
        if let stringValue = value as? String, let intValue = Int(stringValue) { return intValue }
        return nil
    }
}
