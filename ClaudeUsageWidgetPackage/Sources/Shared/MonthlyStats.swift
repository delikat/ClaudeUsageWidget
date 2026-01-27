import Foundation

public struct MonthlyStats: Codable, Sendable, Identifiable {
    public let month: String
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationInputTokens: Int
    public let cacheReadInputTokens: Int
    public let totalCost: Double
    public let models: [ModelBreakdown]

    public var id: String { month }

    public var totalTokens: Int {
        inputTokens + outputTokens + cacheCreationInputTokens + cacheReadInputTokens
    }

    public init(
        month: String,
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationInputTokens: Int,
        cacheReadInputTokens: Int,
        totalCost: Double,
        models: [ModelBreakdown]
    ) {
        self.month = month
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
        self.totalCost = totalCost
        self.models = models
    }

    public static func monthIdentifier(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let year = components.year, let month = components.month else {
            return "0000-00"
        }
        return String(format: "%04d-%02d", year, month)
    }

    public static func monthDate(from identifier: String, calendar: Calendar = .current) -> Date? {
        let parts = identifier.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]) else {
            return nil
        }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        return calendar.date(from: components)
    }
}

public struct ModelBreakdown: Codable, Sendable, Identifiable {
    public let model: String
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationInputTokens: Int
    public let cacheReadInputTokens: Int
    public let totalCost: Double

    public var id: String { model }

    public init(
        model: String,
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationInputTokens: Int,
        cacheReadInputTokens: Int,
        totalCost: Double
    ) {
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
        self.totalCost = totalCost
    }
}

public struct CachedMonthlyUsage: Codable, Sendable {
    public let months: [MonthlyStats]
    public let fetchedAt: Date
    public let error: CacheError?

    public enum CacheError: String, Codable, Sendable {
        case noData
        case readError
    }

    public init(months: [MonthlyStats], fetchedAt: Date, error: CacheError?) {
        self.months = months
        self.fetchedAt = fetchedAt
        self.error = error
    }

    public static var placeholder: CachedMonthlyUsage {
        let sample = MonthlyStats(
            month: MonthlyStats.monthIdentifier(for: Date()),
            inputTokens: 120_000,
            outputTokens: 60_000,
            cacheCreationInputTokens: 30_000,
            cacheReadInputTokens: 10_000,
            totalCost: 12.34,
            models: [
                ModelBreakdown(
                    model: "claude-opus-4",
                    inputTokens: 80_000,
                    outputTokens: 40_000,
                    cacheCreationInputTokens: 20_000,
                    cacheReadInputTokens: 5_000,
                    totalCost: 9.87
                ),
                ModelBreakdown(
                    model: "claude-sonnet-4",
                    inputTokens: 40_000,
                    outputTokens: 20_000,
                    cacheCreationInputTokens: 10_000,
                    cacheReadInputTokens: 5_000,
                    totalCost: 2.47
                )
            ]
        )
        return CachedMonthlyUsage(months: [sample], fetchedAt: Date(), error: nil)
    }

    public static var noData: CachedMonthlyUsage {
        CachedMonthlyUsage(months: [], fetchedAt: Date(), error: .noData)
    }
}

public struct MonthlyUsageSample: Sendable {
    public let month: String
    public let model: String
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationInputTokens: Int
    public let cacheReadInputTokens: Int
    public let costUSD: Double

    public init(
        month: String,
        model: String,
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationInputTokens: Int,
        cacheReadInputTokens: Int,
        costUSD: Double
    ) {
        self.month = month
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
        self.costUSD = costUSD
    }
}

public struct MonthlyStatsAggregator {
    public static func aggregate(samples: [MonthlyUsageSample]) -> [MonthlyStats] {
        var monthModelMap: [String: [String: MonthlyUsageSample]] = [:]

        for sample in samples {
            var models = monthModelMap[sample.month] ?? [:]
            if let existing = models[sample.model] {
                models[sample.model] = MonthlyUsageSample(
                    month: sample.month,
                    model: sample.model,
                    inputTokens: existing.inputTokens + sample.inputTokens,
                    outputTokens: existing.outputTokens + sample.outputTokens,
                    cacheCreationInputTokens: existing.cacheCreationInputTokens + sample.cacheCreationInputTokens,
                    cacheReadInputTokens: existing.cacheReadInputTokens + sample.cacheReadInputTokens,
                    costUSD: existing.costUSD + sample.costUSD
                )
            } else {
                models[sample.model] = sample
            }
            monthModelMap[sample.month] = models
        }

        return monthModelMap.map { month, models in
            let modelBreakdowns: [ModelBreakdown] = models.values.map { sample in
                ModelBreakdown(
                    model: sample.model,
                    inputTokens: sample.inputTokens,
                    outputTokens: sample.outputTokens,
                    cacheCreationInputTokens: sample.cacheCreationInputTokens,
                    cacheReadInputTokens: sample.cacheReadInputTokens,
                    totalCost: sample.costUSD
                )
            }
            let totals = modelBreakdowns.reduce(into: (0, 0, 0, 0, 0.0)) { result, breakdown in
                result.0 += breakdown.inputTokens
                result.1 += breakdown.outputTokens
                result.2 += breakdown.cacheCreationInputTokens
                result.3 += breakdown.cacheReadInputTokens
                result.4 += breakdown.totalCost
            }

            return MonthlyStats(
                month: month,
                inputTokens: totals.0,
                outputTokens: totals.1,
                cacheCreationInputTokens: totals.2,
                cacheReadInputTokens: totals.3,
                totalCost: totals.4,
                models: modelBreakdowns.sorted { $0.totalCost > $1.totalCost }
            )
        }
        .sorted { $0.month > $1.month }
    }
}
