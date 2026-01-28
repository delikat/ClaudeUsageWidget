import XCTest
@testable import Shared

@MainActor
final class GaugeWidgetSnapshotTests: SnapshotTestCase {
    func testSmallGaugeVariants() {
        assertSnapshotView(
            SnapshotSmallGaugeWidgetView(usage: SnapshotTestData.normalUsage),
            size: SnapshotWidgetSize.small,
            named: "normal"
        )

        assertSnapshotView(
            SnapshotSmallGaugeWidgetView(usage: SnapshotTestData.highUsage),
            size: SnapshotWidgetSize.small,
            named: "high-usage"
        )
    }

    func testMediumGaugeVariants() {
        assertSnapshotView(
            SnapshotMediumGaugeWidgetView(usage: SnapshotTestData.normalUsage),
            size: SnapshotWidgetSize.medium,
            named: "normal"
        )

        assertSnapshotView(
            SnapshotMediumGaugeWidgetView(usage: SnapshotTestData.highUsage),
            size: SnapshotWidgetSize.medium,
            named: "high-usage"
        )
    }
}
