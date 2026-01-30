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

    private var prevTotalInput = 0
    private var prevTotalCached = 0
    private var prevTotalOutput = 0

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

            // Update previous cumulative totals so the delta fallback
            // stays correct even if last/total presence is inconsistent.
            if let cum = cumUsage {
                prevTotalInput = intValue(from: cum["input_tokens"]) ?? prevTotalInput
                prevTotalCached = intValue(from: cum["cached_input_tokens"]) ?? prevTotalCached
                prevTotalOutput = intValue(from: cum["output_tokens"]) ?? prevTotalOutput
            } else {
                prevTotalInput += dInput
                prevTotalCached += dCached
                prevTotalOutput += dOutput
            }

            // Skip zero-delta events
            guard dInput > 0 || dCached > 0 || dOutput > 0 else { return }

            totalInput += dInput
            totalCached += dCached
            totalOutput += dOutput

            if let ts = json["timestamp"] as? String,
               let date = fracFormatter.date(from: ts) ?? plainFormatter.date(from: ts)
            {
                latestTimestamp = date
            }
        }
    }

    private func intValue(from value: Any?) -> Int? {
        if let intValue = value as? Int { return intValue }
        if let doubleValue = value as? Double { return Int(doubleValue) }
        if let stringValue = value as? String, let intValue = Int(stringValue) { return intValue }
        return nil
    }
}
