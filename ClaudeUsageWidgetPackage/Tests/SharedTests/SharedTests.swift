import Foundation
import Testing
@testable import Shared

@Test func testCachedUsagePlaceholder() {
    let placeholder = CachedUsage.placeholder
    #expect(placeholder.fiveHourUsage == 45.0)
    #expect(placeholder.sevenDayUsage == 23.0)
    #expect(placeholder.error == nil)
}

@Test func testCachedUsageNoCredentialsError() {
    let error = CachedUsage.noCredentialsError
    #expect(error.error == .noCredentials)
    #expect(error.fiveHourUsage == 0)
}

@Test func testCodexCachedUsagePlaceholder() {
    let placeholder = CodexCachedUsage.placeholder
    #expect(placeholder.primaryWindow.usedPercent != nil)
    #expect(placeholder.secondaryWindow.usedPercent != nil)
    #expect(placeholder.error == nil)
}

@Test func testCodexSubscriptionUsageDecoding() throws {
    let json = """
    {
      "plan_type": "plus",
      "rate_limit": {
        "primary_window": {
          "window_size_in_hours": 5,
          "usage_limit": 50,
          "used_units": 10,
          "used_percent": 20,
          "resets_at": "2025-01-01T00:00:00Z",
          "reset_from_now": "5 hours"
        },
        "secondary_window": {
          "window_size_in_days": 7,
          "usage_limit": 70,
          "used_units": 7,
          "used_percent": 10,
          "resets_at": "2025-01-07T00:00:00Z",
          "reset_from_now": "7 days"
        }
      }
    }
    """
    let data = Data(json.utf8)
    let decoded = try JSONDecoder().decode(CodexSubscriptionUsageResponse.self, from: data)
    #expect(decoded.planType == "plus")
    #expect(decoded.rateLimit?.primaryWindow?.windowSizeInHours == 5)
    #expect(decoded.rateLimit?.secondaryWindow?.windowSizeInDays == 7)
    #expect(decoded.rateLimit?.primaryWindow?.usedPercent == 20)
}

@Test func testOpenAIUsageBucketDecodesResultsKey() throws {
    let json = """
    {
      "data": [
        {
          "start_time": 10,
          "end_time": 20,
          "results": [
            {
              "input_tokens": 100,
              "output_tokens": 50,
              "num_model_requests": 3
            }
          ]
        }
      ]
    }
    """
    let data = Data(json.utf8)
    let decoded = try JSONDecoder().decode(OpenAIUsagePage.self, from: data)
    #expect(decoded.data.count == 1)
    #expect(decoded.data[0].results.count == 1)
    #expect(decoded.data[0].results[0].inputTokens == 100)
}

@Test func testOpenAIUsageBucketDecodesResultKey() throws {
    let json = """
    {
      "start_time": 10,
      "end_time": 20,
      "result": [
        {
          "input_tokens": 5,
          "output_tokens": 7,
          "num_model_requests": 1
        }
      ]
    }
    """
    let data = Data(json.utf8)
    let decoded = try JSONDecoder().decode(OpenAIUsageBucket.self, from: data)
    #expect(decoded.results.count == 1)
    #expect(decoded.results[0].outputTokens == 7)
}
