import Foundation
import Testing
@testable import Shared

@Test func testClaudeModelPricingCostCalculation() {
    let cost = ClaudeModelPricing.calculateCost(
        model: "claude-opus-4-5-20251101",
        inputTokens: 1_000_000,
        outputTokens: 1_000_000,
        cacheCreationInputTokens: 1_000_000,
        cacheReadInputTokens: 1_000_000
    )
    let expected = 110.25
    #expect(abs(cost - expected) < 0.0001)
}

@Test func testMonthIdentifierFormatting() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    let date = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))!
    #expect(MonthlyStats.monthIdentifier(for: date, calendar: calendar) == "2026-01")
}

@Test func testMonthlyAggregationTotals() {
    let samples = [
        MonthlyUsageSample(
            month: "2026-01",
            model: "claude-opus-4",
            inputTokens: 100,
            outputTokens: 50,
            cacheCreationInputTokens: 20,
            cacheReadInputTokens: 10,
            costUSD: 1.5
        ),
        MonthlyUsageSample(
            month: "2026-01",
            model: "claude-opus-4",
            inputTokens: 40,
            outputTokens: 10,
            cacheCreationInputTokens: 0,
            cacheReadInputTokens: 5,
            costUSD: 0.5
        ),
        MonthlyUsageSample(
            month: "2025-12",
            model: "claude-sonnet-4",
            inputTokens: 200,
            outputTokens: 100,
            cacheCreationInputTokens: 0,
            cacheReadInputTokens: 0,
            costUSD: 2.0
        )
    ]

    let stats = MonthlyStatsAggregator.aggregate(samples: samples)
    #expect(stats.count == 2)
    let january = stats.first { $0.month == "2026-01" }
    #expect(january?.inputTokens == 140)
    #expect(january?.outputTokens == 60)
    #expect(january?.cacheCreationInputTokens == 20)
    #expect(january?.cacheReadInputTokens == 15)
    #expect(abs((january?.totalCost ?? 0) - 2.0) < 0.0001)
    #expect(january?.models.count == 1)
}
