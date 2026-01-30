import Foundation
import Testing
@testable import Shared

// MARK: - Helpers

private func sessionMeta(id: String) -> [String: Any] {
    ["type": "session_meta", "timestamp": "2026-01-15T10:00:00.000Z",
     "payload": ["id": id]]
}

private func turnContext(model: String) -> [String: Any] {
    ["type": "turn_context", "timestamp": "2026-01-15T10:00:01.000Z",
     "payload": ["model": model]]
}

private func tokenCount(
    timestamp: String = "2026-01-15T10:00:02.000Z",
    last: [String: Any]? = nil,
    total: [String: Any]? = nil
) -> [String: Any] {
    var info: [String: Any] = [:]
    info["last_token_usage"] = last
    info["total_token_usage"] = total
    return [
        "type": "event_msg",
        "timestamp": timestamp,
        "payload": ["type": "token_count", "info": info] as [String: Any]
    ]
}

private func usage(input: Int, cached: Int, output: Int, reasoning: Int = 0, total: Int? = nil) -> [String: Any] {
    var dict: [String: Any] = [
        "input_tokens": input,
        "cached_input_tokens": cached,
        "output_tokens": output,
        "reasoning_output_tokens": reasoning,
    ]
    dict["total_tokens"] = total ?? (input + output)
    return dict
}

private func tokenCountWithModel(
    timestamp: String = "2026-01-15T10:00:02.000Z",
    last: [String: Any]? = nil,
    total: [String: Any]? = nil,
    infoExtra: [String: Any] = [:],
    payloadExtra: [String: Any] = [:]
) -> [String: Any] {
    var info: [String: Any] = infoExtra
    info["last_token_usage"] = last
    info["total_token_usage"] = total
    var payload: [String: Any] = payloadExtra
    payload["type"] = "token_count"
    payload["info"] = info
    return [
        "type": "event_msg",
        "timestamp": timestamp,
        "payload": payload
    ]
}

// MARK: - Tests

@Test func testBasicLastTokenUsage() {
    var parser = CodexSessionParser()
    parser.processLine(sessionMeta(id: "sess-1"))
    parser.processLine(turnContext(model: "gpt-5.2-codex"))
    parser.processLine(tokenCount(
        last: usage(input: 1000, cached: 800, output: 50),
        total: usage(input: 1000, cached: 800, output: 50)
    ))
    parser.processLine(tokenCount(
        last: usage(input: 2000, cached: 1500, output: 100),
        total: usage(input: 3000, cached: 2300, output: 150)
    ))

    #expect(parser.sessionId == "sess-1")
    #expect(parser.model == "gpt-5.2-codex")
    #expect(parser.totalInput == 3000)
    #expect(parser.totalCached == 2300)
    #expect(parser.totalOutput == 150)
    #expect(parser.hasUsage)
}

@Test func testCumulativeOnlyFallback() {
    var parser = CodexSessionParser()
    parser.processLine(turnContext(model: "gpt-5.2-codex"))
    // First event: cumulative only, delta = 1000 - 0
    parser.processLine(tokenCount(
        last: nil,
        total: usage(input: 1000, cached: 800, output: 50)
    ))
    // Second event: cumulative only, delta = 3000 - 1000
    parser.processLine(tokenCount(
        last: nil,
        total: usage(input: 3000, cached: 2300, output: 150)
    ))

    #expect(parser.totalInput == 3000)
    #expect(parser.totalCached == 2300)
    #expect(parser.totalOutput == 150)
}

@Test func testMixedLastThenCumulative() {
    // Issue #2: last-only event followed by cumulative-only event
    // should not double-count.
    var parser = CodexSessionParser()
    // Event 1: has last_token_usage only (no total)
    parser.processLine(tokenCount(
        last: usage(input: 500, cached: 400, output: 20),
        total: nil
    ))
    // Event 2: cumulative-only; total includes event 1's tokens
    parser.processLine(tokenCount(
        last: nil,
        total: usage(input: 1200, cached: 900, output: 70)
    ))

    // Event 1 contributed 500 via last; prevTotal advanced to 500.
    // Event 2 delta = 1200 - 500 = 700.
    // Total = 500 + 700 = 1200.
    #expect(parser.totalInput == 1200)
    #expect(parser.totalCached == 900)
    #expect(parser.totalOutput == 70)
}

@Test func testNullInfoSkipped() {
    var parser = CodexSessionParser()
    parser.processLine(turnContext(model: "gpt-5.2-codex"))
    // First token_count event in a session often has info: null
    let nullInfoEvent: [String: Any] = [
        "type": "event_msg",
        "timestamp": "2026-01-15T10:00:02.000Z",
        "payload": ["type": "token_count", "info": NSNull()] as [String: Any]
    ]
    parser.processLine(nullInfoEvent)

    #expect(!parser.hasUsage)
    #expect(parser.latestTimestamp == nil)
}

@Test func testZeroDeltaSkipped() {
    var parser = CodexSessionParser()
    parser.processLine(tokenCount(
        last: usage(input: 1000, cached: 800, output: 50),
        total: usage(input: 1000, cached: 800, output: 50)
    ))
    // Duplicate event with same cumulative total
    parser.processLine(tokenCount(
        last: usage(input: 0, cached: 0, output: 0),
        total: usage(input: 1000, cached: 800, output: 50)
    ))

    #expect(parser.totalInput == 1000)
    #expect(parser.totalOutput == 50)
}

@Test func testTimestampWithoutFractionalSeconds() {
    var parser = CodexSessionParser()
    parser.processLine(tokenCount(
        timestamp: "2026-01-15T10:00:02Z",
        last: usage(input: 100, cached: 50, output: 10),
        total: usage(input: 100, cached: 50, output: 10)
    ))

    #expect(parser.hasUsage)
    #expect(parser.latestTimestamp != nil)
}

@Test func testTimestampWithFractionalSeconds() {
    var parser = CodexSessionParser()
    parser.processLine(tokenCount(
        timestamp: "2026-01-15T10:00:02.123Z",
        last: usage(input: 100, cached: 50, output: 10),
        total: usage(input: 100, cached: 50, output: 10)
    ))

    #expect(parser.hasUsage)
    #expect(parser.latestTimestamp != nil)
}

@Test func testNoUsageEvents() {
    var parser = CodexSessionParser()
    parser.processLine(sessionMeta(id: "sess-empty"))
    parser.processLine(turnContext(model: "gpt-5.2-codex"))

    #expect(!parser.hasUsage)
    #expect(parser.latestTimestamp == nil)
    #expect(parser.model == "gpt-5.2-codex")
}

@Test func testLinesWithoutPayloadIgnored() {
    var parser = CodexSessionParser()
    // Lines missing "payload" should be silently skipped
    parser.processLine(["type": "unknown_event"])
    parser.processLine([:])

    #expect(!parser.hasUsage)
    #expect(parser.sessionId == nil)
    #expect(parser.model == nil)
}

// MARK: - New behavior tests

@Test func testReasoningTokenTracking() {
    var parser = CodexSessionParser()
    parser.processLine(tokenCount(
        last: usage(input: 1000, cached: 200, output: 500, reasoning: 300),
        total: usage(input: 1000, cached: 200, output: 500, reasoning: 300)
    ))
    parser.processLine(tokenCount(
        last: usage(input: 800, cached: 100, output: 400, reasoning: 200),
        total: usage(input: 1800, cached: 300, output: 900, reasoning: 500)
    ))

    #expect(parser.totalReasoning == 500)
    #expect(parser.totalOutput == 900)
}

@Test func testCacheReadInputTokensAlias() {
    var parser = CodexSessionParser()
    // Use cache_read_input_tokens instead of cached_input_tokens
    let lastDict: [String: Any] = [
        "input_tokens": 1000,
        "cache_read_input_tokens": 800,
        "output_tokens": 50,
        "total_tokens": 1050,
    ]
    let totalDict: [String: Any] = [
        "input_tokens": 1000,
        "cache_read_input_tokens": 800,
        "output_tokens": 50,
        "total_tokens": 1050,
    ]
    parser.processLine(tokenCount(last: lastDict, total: totalDict))

    #expect(parser.totalCached == 800)
    #expect(parser.totalInput == 1000)
}

@Test func testModelExtractedFromInfoModel() {
    var parser = CodexSessionParser()
    parser.processLine(tokenCountWithModel(
        last: usage(input: 100, cached: 0, output: 50),
        total: usage(input: 100, cached: 0, output: 50),
        infoExtra: ["model": "o3"]
    ))

    #expect(parser.model == "o3")
}

@Test func testModelExtractedFromInfoModelName() {
    var parser = CodexSessionParser()
    parser.processLine(tokenCountWithModel(
        last: usage(input: 100, cached: 0, output: 50),
        total: usage(input: 100, cached: 0, output: 50),
        infoExtra: ["model_name": "gpt-4o-mini"]
    ))

    #expect(parser.model == "gpt-4o-mini")
}

@Test func testModelExtractedFromInfoMetadata() {
    var parser = CodexSessionParser()
    parser.processLine(tokenCountWithModel(
        last: usage(input: 100, cached: 0, output: 50),
        total: usage(input: 100, cached: 0, output: 50),
        infoExtra: ["metadata": ["model": "gpt-5-mini"] as [String: Any]]
    ))

    #expect(parser.model == "gpt-5-mini")
}

@Test func testModelUpdatedByLaterTurnContext() {
    var parser = CodexSessionParser()
    parser.processLine(turnContext(model: "gpt-5"))
    #expect(parser.model == "gpt-5")

    parser.processLine(tokenCount(
        last: usage(input: 100, cached: 0, output: 50),
        total: usage(input: 100, cached: 0, output: 50)
    ))

    // Later turn_context updates the model (no longer gated on model == nil)
    parser.processLine(turnContext(model: "o4-mini"))
    #expect(parser.model == "o4-mini")
}

@Test func testTotalTokensSynthesizedWhenMissing() {
    var parser = CodexSessionParser()
    // total_tokens = 0 means it should be synthesized as input + output
    let lastDict: [String: Any] = [
        "input_tokens": 1000,
        "cached_input_tokens": 200,
        "output_tokens": 500,
        "total_tokens": 0,
    ]
    let totalDict: [String: Any] = [
        "input_tokens": 1000,
        "cached_input_tokens": 200,
        "output_tokens": 500,
        "total_tokens": 0,
    ]
    parser.processLine(tokenCount(last: lastDict, total: totalDict))

    #expect(parser.totalTokens == 1500)  // 1000 + 500
}

@Test func testTotalTokensUsedWhenPresent() {
    var parser = CodexSessionParser()
    parser.processLine(tokenCount(
        last: usage(input: 1000, cached: 200, output: 500, total: 1700),
        total: usage(input: 1000, cached: 200, output: 500, total: 1700)
    ))

    #expect(parser.totalTokens == 1700)
}

@Test func testReasoningTokensCumulativeOnly() {
    var parser = CodexSessionParser()
    // Cumulative-only events with reasoning tokens
    parser.processLine(tokenCount(
        last: nil,
        total: usage(input: 1000, cached: 200, output: 500, reasoning: 300)
    ))
    parser.processLine(tokenCount(
        last: nil,
        total: usage(input: 2000, cached: 400, output: 900, reasoning: 600)
    ))

    #expect(parser.totalReasoning == 600)
    #expect(parser.totalInput == 2000)
    #expect(parser.totalOutput == 900)
}
