import AppKit
import Foundation
import SnapshotTesting
import SwiftUI
import XCTest
@testable import Shared

enum SnapshotWidgetSize {
    static let small = CGSize(width: 155, height: 155)
    static let medium = CGSize(width: 329, height: 155)
    static let large = CGSize(width: 329, height: 345)
}

enum SnapshotTestData {
    static let claudePlanTitle = "Claude Max 20x"
    static let codexPlanTitle = "ChatGPT Pro"

    static let normalUsage = SnapshotUsageData(
        planTitle: claudePlanTitle,
        fiveHourUsage: 45,
        sevenDayUsage: 23,
        fiveHourResetText: "52m",
        sevenDayResetText: "2d 4h",
        error: nil
    )

    static let highUsage = SnapshotUsageData(
        planTitle: claudePlanTitle,
        fiveHourUsage: 92,
        sevenDayUsage: 88,
        fiveHourResetText: "12m",
        sevenDayResetText: "11h",
        error: nil
    )

    static func errorUsage(_ error: CachedUsage.CacheError) -> SnapshotUsageData {
        SnapshotUsageData(
            planTitle: nil,
            fiveHourUsage: 0,
            sevenDayUsage: 0,
            fiveHourResetText: nil,
            sevenDayResetText: nil,
            error: error
        )
    }

    static let codexNormalUsage = SnapshotUsageData(
        planTitle: codexPlanTitle,
        fiveHourUsage: 37,
        sevenDayUsage: 19,
        fiveHourResetText: "44m",
        sevenDayResetText: "3d",
        error: nil
    )

    static let codexHighUsage = SnapshotUsageData(
        planTitle: codexPlanTitle,
        fiveHourUsage: 95,
        sevenDayUsage: 91,
        fiveHourResetText: "8m",
        sevenDayResetText: "9h",
        error: nil
    )

    static let monthlyStats = MonthlyStats(
        month: "2025-12",
        inputTokens: 120_000,
        outputTokens: 60_000,
        cacheCreationInputTokens: 30_000,
        cacheReadInputTokens: 10_000,
        totalCost: 12.34,
        models: [
            ModelBreakdown(
                model: "claude-opus-4",
                inputTokens: 80_000,
                outputTokens: 40_000,
                cacheCreationInputTokens: 20_000,
                cacheReadInputTokens: 5_000,
                totalCost: 9.87
            ),
            ModelBreakdown(
                model: "claude-sonnet-4",
                inputTokens: 40_000,
                outputTokens: 20_000,
                cacheCreationInputTokens: 10_000,
                cacheReadInputTokens: 5_000,
                totalCost: 2.47
            )
        ]
    )

    static let monthlyData = SnapshotMonthlyData(stats: monthlyStats, error: nil)
    static let monthlyError = SnapshotMonthlyData(stats: nil, error: .noData)

    static let heatmapReferenceDate: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        var components = DateComponents()
        components.year = 2025
        components.month = 12
        components.day = 15
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }()

    static let heatmapHistory: UsageHistory = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        var entries: [DailyUsage] = []
        for dayOffset in 0..<35 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: heatmapReferenceDate) else {
                continue
            }
            let dateString = formatter.string(from: date)
            let claudeTokens = (dayOffset % 7 == 0) ? 0 : 1_500 + dayOffset * 120
            let codexTokens = (dayOffset % 5 == 0) ? 0 : 900 + dayOffset * 80
            entries.append(DailyUsage(date: dateString, claudeTokens: claudeTokens, codexTokens: codexTokens))
        }
        return UsageHistory(entries: entries)
    }()
}

enum SnapshotTestConfig {
    static let recordMode: SnapshotTestingConfiguration.Record? = {
        guard let value = ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"]?.lowercased() else {
            return nil
        }
        if value == "1" || value == "true" || value == "yes" || value == "all" {
            return .all
        }
        if value == "missing" {
            return .missing
        }
        if value == "failed" {
            return .failed
        }
        if value == "never" || value == "0" || value == "false" || value == "no" {
            return .never
        }
        return SnapshotTestingConfiguration.Record(rawValue: value)
    }()

    static let shouldSkip: Bool = {
        let env = ProcessInfo.processInfo.environment
        let ciValue = env["CI"]?.lowercased()
        let isCI = ciValue == "1" || ciValue == "true" || ciValue == "yes"
        let runSnapshotsValue = env["RUN_SNAPSHOT_TESTS"]?.lowercased()
        let runSnapshots = runSnapshotsValue == "1" || runSnapshotsValue == "true" || runSnapshotsValue == "yes"
        return isCI && !runSnapshots
    }()
}

class SnapshotTestCase: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        if SnapshotTestConfig.shouldSkip {
            throw XCTSkip("Snapshot tests are disabled on CI. Set RUN_SNAPSHOT_TESTS=1 to enable.")
        }
    }

    override func invokeTest() {
        if let record = SnapshotTestConfig.recordMode {
            withSnapshotTesting(record: record) {
                super.invokeTest()
            }
        } else {
            super.invokeTest()
        }
    }
}

struct SnapshotHost<Content: View>: View {
    let size: CGSize
    let content: Content

    init(size: CGSize, @ViewBuilder content: () -> Content) {
        self.size = size
        self.content = content()
    }

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            content
        }
        .frame(width: size.width, height: size.height)
        .environment(\.colorScheme, .light)
        .environment(\.locale, Locale(identifier: "en_US_POSIX"))
    }
}

@MainActor
func assertSnapshotView<V: View>(
    _ view: V,
    size: CGSize,
    named: String? = nil,
    file: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line
) {
    let host = SnapshotHost(size: size) { view }
    let hostingView = NSHostingView(rootView: host)
    hostingView.frame = CGRect(origin: .zero, size: size)
    if let named {
        assertSnapshot(
            of: hostingView,
            as: .image(size: size),
            named: named,
            file: file,
            testName: testName,
            line: line
        )
    } else {
        assertSnapshot(
            of: hostingView,
            as: .image(size: size),
            file: file,
            testName: testName,
            line: line
        )
    }
}

@MainActor
func renderSnapshotPNG<V: View>(
    _ view: V,
    size: CGSize
) throws -> Data {
    let host = SnapshotHost(size: size) { view }
    let renderer = ImageRenderer(content: host)
    renderer.scale = 2
    renderer.proposedSize = ProposedViewSize(size)
    guard let image = renderer.nsImage else {
        throw NSError(domain: "SnapshotRender", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to render image"])
    }
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "SnapshotRender", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG"])
    }
    return pngData
}
