import Foundation

public struct ModelPricing: Codable, Sendable {
    public let inputPerMillion: Double
    public let outputPerMillion: Double
    public let cacheCreationMultiplier: Double
    public let cacheReadMultiplier: Double

    public init(
        inputPerMillion: Double,
        outputPerMillion: Double,
        cacheCreationMultiplier: Double = 1.25,
        cacheReadMultiplier: Double = 0.1
    ) {
        self.inputPerMillion = inputPerMillion
        self.outputPerMillion = outputPerMillion
        self.cacheCreationMultiplier = cacheCreationMultiplier
        self.cacheReadMultiplier = cacheReadMultiplier
    }
}

public enum ClaudeModelPricing {
    private static let opus = ModelPricing(inputPerMillion: 15.0, outputPerMillion: 75.0)
    private static let sonnet = ModelPricing(inputPerMillion: 3.0, outputPerMillion: 15.0)
    private static let haiku = ModelPricing(inputPerMillion: 0.80, outputPerMillion: 4.0)

    public static func pricing(for model: String) -> ModelPricing? {
        let lowercased = model.lowercased()
        if lowercased.contains("opus") {
            return opus
        }
        if lowercased.contains("sonnet") {
            return sonnet
        }
        if lowercased.contains("haiku") {
            return haiku
        }
        return nil
    }

    public static func calculateCost(
        model: String,
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationInputTokens: Int,
        cacheReadInputTokens: Int
    ) -> Double {
        guard let pricing = pricing(for: model) else {
            return 0
        }

        let million: Double = 1_000_000
        let inputCost = (Double(inputTokens) / million) * pricing.inputPerMillion
        let outputCost = (Double(outputTokens) / million) * pricing.outputPerMillion
        let cacheCreationCost = (Double(cacheCreationInputTokens) / million)
            * pricing.inputPerMillion
            * pricing.cacheCreationMultiplier
        let cacheReadCost = (Double(cacheReadInputTokens) / million)
            * pricing.inputPerMillion
            * pricing.cacheReadMultiplier
        return inputCost + outputCost + cacheCreationCost + cacheReadCost
    }
}
