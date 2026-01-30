import Foundation
import Testing
@testable import Shared

@Test func testGPT5CostCalculation() {
    let cost = CodexModelPricing.calculateCost(
        model: "gpt-5",
        inputTokens: 1_000_000,
        outputTokens: 1_000_000,
        cacheCreationInputTokens: 0,
        cacheReadInputTokens: 0
    )
    // input: 1.25 + output: 10.0 = 11.25
    #expect(abs(cost - 11.25) < 0.001)
}

@Test func testO3CostCalculation() {
    let cost = CodexModelPricing.calculateCost(
        model: "o3",
        inputTokens: 1_000_000,
        outputTokens: 1_000_000,
        cacheCreationInputTokens: 0,
        cacheReadInputTokens: 0
    )
    // input: 2.0 + output: 8.0 = 10.0
    #expect(abs(cost - 10.0) < 0.001)
}

@Test func testUnknownModelReturnsZero() {
    let cost = CodexModelPricing.calculateCost(
        model: "unknown-model-xyz",
        inputTokens: 1_000_000,
        outputTokens: 1_000_000,
        cacheCreationInputTokens: 0,
        cacheReadInputTokens: 0
    )
    #expect(cost == 0)
}

@Test func testModelNameWithSuffixMatches() {
    // "gpt-5-codex" should still match gpt-5
    let cost = CodexModelPricing.calculateCost(
        model: "gpt-5-codex",
        inputTokens: 1_000_000,
        outputTokens: 1_000_000,
        cacheCreationInputTokens: 0,
        cacheReadInputTokens: 0
    )
    // input: 1.25 + output: 10.0 = 11.25
    #expect(abs(cost - 11.25) < 0.001)
}

@Test func testGPT5MiniMatchedBeforeGPT5() {
    let pricing = CodexModelPricing.pricing(for: "gpt-5-mini")
    // gpt-5-mini has inputPerMillion: 0.30, not 1.25
    #expect(pricing != nil)
    #expect(abs(pricing!.inputPerMillion - 0.30) < 0.001)
}

@Test func testCacheReadCost() {
    let cost = CodexModelPricing.calculateCost(
        model: "gpt-5",
        inputTokens: 0,
        outputTokens: 0,
        cacheCreationInputTokens: 0,
        cacheReadInputTokens: 1_000_000
    )
    // cacheRead: 1.25 * 0.10 = 0.125
    #expect(abs(cost - 0.125) < 0.001)
}

@Test func testO4MiniPricing() {
    let pricing = CodexModelPricing.pricing(for: "o4-mini")
    #expect(pricing != nil)
    #expect(abs(pricing!.inputPerMillion - 1.10) < 0.001)
    #expect(abs(pricing!.outputPerMillion - 4.40) < 0.001)
}
