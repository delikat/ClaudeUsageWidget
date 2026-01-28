import XCTest
@testable import Shared

@MainActor
final class ClaudeWidgetSnapshotTests: SnapshotTestCase {
    private let errorCases: [CachedUsage.CacheError] = [
        .noCredentials,
        .networkError,
        .invalidToken,
        .apiError,
        .invalidCredentialsFormat,
    ]

    func testSmallWidgetVariants() {
        assertSnapshotView(
            SnapshotSmallWidgetView(usage: SnapshotTestData.normalUsage),
            size: SnapshotWidgetSize.small,
            named: "normal"
        )

        assertSnapshotView(
            SnapshotSmallWidgetView(usage: SnapshotTestData.highUsage),
            size: SnapshotWidgetSize.small,
            named: "high-usage"
        )

        for error in errorCases {
            assertSnapshotView(
                SnapshotSmallWidgetView(usage: SnapshotTestData.errorUsage(error)),
                size: SnapshotWidgetSize.small,
                named: "error-\(error.rawValue)"
            )
        }
    }

    func testMediumWidgetVariants() {
        assertSnapshotView(
            SnapshotMediumWidgetView(usage: SnapshotTestData.normalUsage),
            size: SnapshotWidgetSize.medium,
            named: "normal"
        )

        assertSnapshotView(
            SnapshotMediumWidgetView(usage: SnapshotTestData.highUsage),
            size: SnapshotWidgetSize.medium,
            named: "high-usage"
        )

        for error in errorCases {
            assertSnapshotView(
                SnapshotMediumWidgetView(usage: SnapshotTestData.errorUsage(error)),
                size: SnapshotWidgetSize.medium,
                named: "error-\(error.rawValue)"
            )
        }
    }

    func testLargeWidgetVariants() {
        assertSnapshotView(
            SnapshotLargeWidgetView(usage: SnapshotTestData.normalUsage, monthly: SnapshotTestData.monthlyData),
            size: SnapshotWidgetSize.large,
            named: "normal"
        )

        assertSnapshotView(
            SnapshotLargeWidgetView(usage: SnapshotTestData.normalUsage, monthly: SnapshotTestData.monthlyError),
            size: SnapshotWidgetSize.large,
            named: "error"
        )
    }
}
