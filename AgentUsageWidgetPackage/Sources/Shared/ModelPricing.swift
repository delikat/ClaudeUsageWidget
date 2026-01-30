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

public enum CodexModelPricing {
    private static let gpt5 = ModelPricing(
        inputPerMillion: 1.25, outputPerMillion: 10.0,
        cacheCreationMultiplier: 1.0, cacheReadMultiplier: 0.10
    )
    private static let gpt5Mini = ModelPricing(
        inputPerMillion: 0.30, outputPerMillion: 1.25,
        cacheCreationMultiplier: 1.0, cacheReadMultiplier: 0.10
    )
    private static let o3 = ModelPricing(
        inputPerMillion: 2.0, outputPerMillion: 8.0,
        cacheCreationMultiplier: 1.0, cacheReadMultiplier: 0.25
    )
    private static let o4Mini = ModelPricing(
        inputPerMillion: 1.10, outputPerMillion: 4.40,
        cacheCreationMultiplier: 1.0, cacheReadMultiplier: 0.227
    )
    private static let gpt4o = ModelPricing(
        inputPerMillion: 2.50, outputPerMillion: 10.0,
        cacheCreationMultiplier: 1.0, cacheReadMultiplier: 0.50
    )
    private static let gpt4oMini = ModelPricing(
        inputPerMillion: 0.15, outputPerMillion: 0.60,
        cacheCreationMultiplier: 1.0, cacheReadMultiplier: 0.50
    )

    public static func pricing(for model: String) -> ModelPricing? {
        let lowercased = model.lowercased()
        // Check specific patterns before broader ones
        if lowercased.contains("gpt-5-mini") { return gpt5Mini }
        if lowercased.contains("gpt-4o-mini") { return gpt4oMini }
        if lowercased.contains("o4-mini") { return o4Mini }
        if lowercased.contains("gpt-5") { return gpt5 }
        if lowercased.contains("gpt-4o") { return gpt4o }
        if lowercased.contains("o3") { return o3 }
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
