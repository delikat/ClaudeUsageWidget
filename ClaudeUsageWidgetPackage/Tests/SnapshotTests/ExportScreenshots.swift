import Foundation
import SwiftUI
import XCTest
@testable import Shared

@MainActor
final class ExportScreenshots: XCTestCase {
    func testExportScreenshots() throws {
        guard ProcessInfo.processInfo.environment["EXPORT_SCREENSHOTS"] == "1" else {
            throw XCTSkip("Set EXPORT_SCREENSHOTS=1 to export snapshot PNGs.")
        }

        let outputDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Screenshots")
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let specs: [(name: String, size: CGSize, view: AnyView)] = [
            ("claude-small", SnapshotWidgetSize.small, AnyView(SnapshotSmallWidgetView(usage: SnapshotTestData.normalUsage))),
            ("claude-medium", SnapshotWidgetSize.medium, AnyView(SnapshotMediumWidgetView(usage: SnapshotTestData.normalUsage))),
            ("claude-large", SnapshotWidgetSize.large, AnyView(SnapshotLargeWidgetView(usage: SnapshotTestData.normalUsage, monthly: SnapshotTestData.monthlyData))),
            ("claude-gauge-small", SnapshotWidgetSize.small, AnyView(SnapshotSmallGaugeWidgetView(usage: SnapshotTestData.normalUsage))),
            ("claude-gauge-medium", SnapshotWidgetSize.medium, AnyView(SnapshotMediumGaugeWidgetView(usage: SnapshotTestData.normalUsage))),
            ("heatmap-large", SnapshotWidgetSize.large, AnyView(SnapshotLargeHeatmapWidgetView(history: SnapshotTestData.heatmapHistory, referenceDate: SnapshotTestData.heatmapReferenceDate))),
            ("codex-small", SnapshotWidgetSize.small, AnyView(SnapshotCodexSmallWidgetView(usage: SnapshotTestData.codexNormalUsage))),
            ("codex-medium", SnapshotWidgetSize.medium, AnyView(SnapshotCodexMediumWidgetView(usage: SnapshotTestData.codexNormalUsage))),
        ]

        for spec in specs {
            let pngData = try renderSnapshotPNG(spec.view, size: spec.size)
            let destination = outputDir.appendingPathComponent("\(spec.name).png")
            try pngData.write(to: destination)
        }
    }
}
