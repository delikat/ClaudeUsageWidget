import XCTest
@testable import Shared

@MainActor
final class CodexWidgetSnapshotTests: SnapshotTestCase {
    private let errorCases: [CachedUsage.CacheError] = [
        .noCredentials,
        .networkError,
        .invalidToken,
        .apiError,
        .invalidCredentialsFormat,
    ]

    func testCodexSmallWidgetVariants() {
        assertSnapshotView(
            SnapshotCodexSmallWidgetView(usage: SnapshotTestData.codexNormalUsage),
            size: SnapshotWidgetSize.small,
            named: "normal"
        )

        assertSnapshotView(
            SnapshotCodexSmallWidgetView(usage: SnapshotTestData.codexHighUsage),
            size: SnapshotWidgetSize.small,
            named: "high-usage"
        )

        for error in errorCases {
            assertSnapshotView(
                SnapshotCodexSmallWidgetView(usage: SnapshotTestData.errorUsage(error)),
                size: SnapshotWidgetSize.small,
                named: "error-\(error.rawValue)"
            )
        }
    }

    func testCodexMediumWidgetVariants() {
        assertSnapshotView(
            SnapshotCodexMediumWidgetView(usage: SnapshotTestData.codexNormalUsage),
            size: SnapshotWidgetSize.medium,
            named: "normal"
        )

        assertSnapshotView(
            SnapshotCodexMediumWidgetView(usage: SnapshotTestData.codexHighUsage),
            size: SnapshotWidgetSize.medium,
            named: "high-usage"
        )

        for error in errorCases {
            assertSnapshotView(
                SnapshotCodexMediumWidgetView(usage: SnapshotTestData.errorUsage(error)),
                size: SnapshotWidgetSize.medium,
                named: "error-\(error.rawValue)"
            )
        }
    }
}
