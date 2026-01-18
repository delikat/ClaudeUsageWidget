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
