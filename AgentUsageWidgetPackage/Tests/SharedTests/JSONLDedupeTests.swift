import Testing
@testable import Shared

@Test func testAcceptSampleOnlyTracksWhenSamplePresent() {
    var seen: Set<String> = []
    let key = "req-1"
    let sample = MonthlyUsageSample(
        month: "2026-01",
        model: "test-model",
        inputTokens: 1,
        outputTokens: 2,
        cacheCreationInputTokens: 0,
        cacheReadInputTokens: 0,
        costUSD: 0.01
    )

    #expect(JSONLDedupe.acceptSample(nil, dedupeKey: key, seenKeys: &seen) == nil)
    #expect(seen.isEmpty)

    #expect(JSONLDedupe.acceptSample(sample, dedupeKey: key, seenKeys: &seen) != nil)
    #expect(seen.contains(key))

    #expect(JSONLDedupe.acceptSample(sample, dedupeKey: key, seenKeys: &seen) == nil)
}

@Test func testExtractDedupeKeyVariants() {
    let requestId = "request-123"
    let uuid = "uuid-456"

    #expect(JSONLDedupe.extractDedupeKey(from: ["requestId": requestId]) == requestId)
    #expect(JSONLDedupe.extractDedupeKey(from: ["request_id": requestId]) == requestId)
    #expect(JSONLDedupe.extractDedupeKey(from: ["response": ["id": requestId]]) == requestId)
    #expect(JSONLDedupe.extractDedupeKey(from: ["message": ["id": requestId]]) == requestId)
    #expect(JSONLDedupe.extractDedupeKey(from: ["uuid": uuid]) == uuid)
}
