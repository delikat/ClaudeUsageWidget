import XCTest
@testable import Shared

@MainActor
final class HeatmapWidgetSnapshotTests: SnapshotTestCase {
    func testHeatmapLarge() {
        assertSnapshotView(
            SnapshotLargeHeatmapWidgetView(
                history: SnapshotTestData.heatmapHistory,
                referenceDate: SnapshotTestData.heatmapReferenceDate
            ),
            size: SnapshotWidgetSize.large,
            named: "normal"
        )
    }
}
