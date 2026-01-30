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

@Test func testCodexUsageResponseDecoding() throws {
    let json = """
    {
      "plan_type": "pro",
      "rate_limit": {
        "allowed": true,
        "limit_reached": false,
        "primary_window": {
          "used_percent": 12,
          "limit_window_seconds": 18000,
          "reset_after_seconds": 3600,
          "reset_at": 1735689600
        },
        "secondary_window": {
          "used_percent": 34,
          "limit_window_seconds": 604800,
          "reset_after_seconds": 86400,
          "reset_at": 1736294400
        }
      },
      "credits": {
        "has_credits": true,
        "unlimited": false,
        "balance": "123.45"
      }
    }
    """
    let data = Data(json.utf8)
    let decoded = try JSONDecoder().decode(CodexUsageResponse.self, from: data)
    #expect(decoded.planType == "pro")
    #expect(decoded.rateLimit.primaryWindow.usedPercent == 12)
    #expect(decoded.rateLimit.secondaryWindow.usedPercent == 34)
    #expect(decoded.credits.hasCredits == true)
    #expect(decoded.credits.unlimited == false)
    #expect(decoded.credits.balance == "123.45")
}
