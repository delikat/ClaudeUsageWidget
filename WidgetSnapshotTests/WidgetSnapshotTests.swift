import XCTest
import SwiftUI
import WidgetKit
import AppKit
import Shared
@testable import AgentUsageWidgetExtension
@testable import CodexUsageWidgetExtension

final class WidgetSnapshotTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        SnapshotEnvironment.configureForDeterministicOutput()
    }

    @MainActor
    func testRenderAllWidgetSnapshots() throws {
        let outputDirectory = SnapshotOutput.outputDirectory()
        print("Widget snapshots output: \(outputDirectory.path)")
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let now = Date()
        let fixtures = SnapshotFixtures(now: now)

        try renderClaudeSnapshots(fixtures: fixtures, outputDirectory: outputDirectory)
        try renderCodexSnapshots(fixtures: fixtures, outputDirectory: outputDirectory)
        try renderHeatmapSnapshot(fixtures: fixtures, outputDirectory: outputDirectory)
    }
}

// MARK: - Snapshot Rendering

@MainActor
private func renderClaudeSnapshots(fixtures: SnapshotFixtures, outputDirectory: URL) throws {
    let entry = UsageEntry(date: fixtures.now, usage: fixtures.claudeUsage, monthly: fixtures.claudeMonthly)

    let variants: [ColorScheme] = [.light, .dark]

    for scheme in variants {
        try renderSnapshot(
            name: "claude-small",
            family: .systemSmall,
            colorScheme: scheme,
            outputDirectory: outputDirectory,
            view: SmallWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        )

        try renderSnapshot(
            name: "claude-medium",
            family: .systemMedium,
            colorScheme: scheme,
            outputDirectory: outputDirectory,
            view: MediumWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        )

        try renderSnapshot(
            name: "claude-large",
            family: .systemLarge,
            colorScheme: scheme,
            outputDirectory: outputDirectory,
            view: LargeWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        )

        try renderSnapshot(
            name: "claude-gauge-small",
            family: .systemSmall,
            colorScheme: scheme,
            outputDirectory: outputDirectory,
            view: SmallGaugeWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        )

        try renderSnapshot(
            name: "claude-gauge-medium",
            family: .systemMedium,
            colorScheme: scheme,
            outputDirectory: outputDirectory,
            view: MediumGaugeWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        )
    }
}

@MainActor
private func renderCodexSnapshots(fixtures: SnapshotFixtures, outputDirectory: URL) throws {
    let entry = CodexUsageEntry(date: fixtures.now, usage: fixtures.codexUsage, monthly: fixtures.codexMonthly)

    let variants: [ColorScheme] = [.light, .dark]

    for scheme in variants {
        try renderSnapshot(
            name: "codex-small",
            family: .systemSmall,
            colorScheme: scheme,
            outputDirectory: outputDirectory,
            view: CodexSmallWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        )

        try renderSnapshot(
            name: "codex-medium",
            family: .systemMedium,
            colorScheme: scheme,
            outputDirectory: outputDirectory,
            view: CodexMediumWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        )

        try renderSnapshot(
            name: "codex-large",
            family: .systemLarge,
            colorScheme: scheme,
            outputDirectory: outputDirectory,
            view: CodexLargeWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        )

        try renderSnapshot(
            name: "codex-gauge-small",
            family: .systemSmall,
            colorScheme: scheme,
            outputDirectory: outputDirectory,
            view: CodexSmallGaugeWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        )

        try renderSnapshot(
            name: "codex-gauge-medium",
            family: .systemMedium,
            colorScheme: scheme,
            outputDirectory: outputDirectory,
            view: CodexMediumGaugeWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        )
    }
}

@MainActor
private func renderHeatmapSnapshot(fixtures: SnapshotFixtures, outputDirectory: URL) throws {
    let entry = HeatmapEntry(date: fixtures.now, history: fixtures.history)

    let variants: [ColorScheme] = [.light, .dark]

    for scheme in variants {
        try renderSnapshot(
            name: "claude-heatmap-large",
            family: .systemLarge,
            colorScheme: scheme,
            outputDirectory: outputDirectory,
            view: LargeHeatmapWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        )
    }
}

@MainActor
private func renderSnapshot<ViewType: View>(
    name: String,
    family: WidgetFamily,
    colorScheme: ColorScheme,
    outputDirectory: URL,
    view: ViewType
) throws {
    let size = widgetSize(for: family)
    let outputURL = outputDirectory.appendingPathComponent(snapshotFileName(base: name, colorScheme: colorScheme))

    let content = view
        .frame(width: size.width, height: size.height)
        .environment(\.colorScheme, colorScheme)
        .environment(\.locale, SnapshotEnvironment.locale)
        .environment(\.timeZone, SnapshotEnvironment.timeZone)

    let renderer = ImageRenderer(content: content)
    renderer.scale = 2

    guard let image = renderer.nsImage else {
        throw SnapshotError.renderFailed(name)
    }

    try SnapshotOutput.writePNG(image, to: outputURL)
}

private func widgetSize(for family: WidgetFamily) -> CGSize {
    switch family {
    case .systemSmall:
        return CGSize(width: 160, height: 160)
    case .systemMedium:
        return CGSize(width: 338, height: 160)
    case .systemLarge:
        return CGSize(width: 338, height: 354)
    default:
        return CGSize(width: 160, height: 160)
    }
}

private func snapshotFileName(base: String, colorScheme: ColorScheme) -> String {
    let suffix = (colorScheme == .dark) ? "-dark" : ""
    return "\(base)\(suffix).png"
}

// MARK: - Fixtures

private struct SnapshotFixtures {
    let now: Date
    let claudeUsage: CachedUsage
    let codexUsage: CachedUsage
    let claudeMonthly: CachedMonthlyUsage
    let codexMonthly: CachedMonthlyUsage
    let history: UsageHistory

    init(now: Date) {
        self.now = now
        self.claudeUsage = SnapshotFixtures.makeUsage(
            now: now,
            planTitle: "Claude Max 20x",
            fiveHourUsage: 64,
            sevenDayUsage: 38
        )
        self.codexUsage = SnapshotFixtures.makeUsage(
            now: now,
            planTitle: "Codex Pro",
            fiveHourUsage: 52,
            sevenDayUsage: 29
        )
        self.claudeMonthly = SnapshotFixtures.makeMonthly(
            now: now,
            totalCost: 12.34,
            inputTokens: 120_000,
            outputTokens: 62_500,
            cacheCreationInputTokens: 28_000,
            cacheReadInputTokens: 14_000,
            models: [
                ModelBreakdown(
                    model: "claude-opus-4",
                    inputTokens: 78_000,
                    outputTokens: 40_000,
                    cacheCreationInputTokens: 18_000,
                    cacheReadInputTokens: 8_000,
                    totalCost: 9.87
                ),
                ModelBreakdown(
                    model: "claude-sonnet-4",
                    inputTokens: 42_000,
                    outputTokens: 22_500,
                    cacheCreationInputTokens: 10_000,
                    cacheReadInputTokens: 6_000,
                    totalCost: 2.47
                )
            ]
        )
        self.codexMonthly = SnapshotFixtures.makeMonthly(
            now: now,
            totalCost: 18.76,
            inputTokens: 210_000,
            outputTokens: 95_000,
            cacheCreationInputTokens: 40_000,
            cacheReadInputTokens: 22_000,
            models: [
                ModelBreakdown(
                    model: "gpt-4.1",
                    inputTokens: 140_000,
                    outputTokens: 70_000,
                    cacheCreationInputTokens: 26_000,
                    cacheReadInputTokens: 12_000,
                    totalCost: 13.42
                ),
                ModelBreakdown(
                    model: "o1-mini",
                    inputTokens: 70_000,
                    outputTokens: 25_000,
                    cacheCreationInputTokens: 14_000,
                    cacheReadInputTokens: 10_000,
                    totalCost: 5.34
                )
            ]
        )
        self.history = SnapshotFixtures.makeHistory(now: now)
    }

    private static func makeUsage(
        now: Date,
        planTitle: String,
        fiveHourUsage: Double,
        sevenDayUsage: Double
    ) -> CachedUsage {
        CachedUsage(
            fiveHourUsage: fiveHourUsage,
            fiveHourResetAt: now.addingTimeInterval(45 * 60),
            sevenDayUsage: sevenDayUsage,
            sevenDayResetAt: now.addingTimeInterval(2 * 24 * 60 * 60 + 3 * 60 * 60),
            fetchedAt: now.addingTimeInterval(-12 * 60),
            error: nil,
            planTitle: planTitle
        )
    }

    private static func makeMonthly(
        now: Date,
        totalCost: Double,
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationInputTokens: Int,
        cacheReadInputTokens: Int,
        models: [ModelBreakdown]
    ) -> CachedMonthlyUsage {
        let monthIdentifier = MonthlyStats.monthIdentifier(for: now, calendar: SnapshotEnvironment.calendar)
        let stats = MonthlyStats(
            month: monthIdentifier,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationInputTokens: cacheCreationInputTokens,
            cacheReadInputTokens: cacheReadInputTokens,
            totalCost: totalCost,
            models: models
        )
        return CachedMonthlyUsage(months: [stats], fetchedAt: now, error: nil)
    }

    private static func makeHistory(now: Date) -> UsageHistory {
        var calendar = SnapshotEnvironment.calendar
        calendar.timeZone = SnapshotEnvironment.timeZone
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = SnapshotEnvironment.timeZone
        formatter.locale = SnapshotEnvironment.locale
        formatter.dateFormat = "yyyy-MM-dd"

        var entries: [DailyUsage] = []
        for dayOffset in 0..<35 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let dateString = formatter.string(from: date)

            let trend = max(0, 34 - dayOffset)
            let baseTokens = 1200 + (trend * 900)
            let claudeTokens = (dayOffset % 6 == 0) ? 0 : baseTokens + (dayOffset % 4) * 750
            let codexTokens = (dayOffset % 5 == 0) ? 0 : Int(Double(baseTokens) * 0.55) + (dayOffset % 3) * 500

            entries.append(DailyUsage(date: dateString, claudeTokens: claudeTokens, codexTokens: codexTokens))
        }

        return UsageHistory(entries: entries, fetchedAt: now)
    }
}

// MARK: - Output

private enum SnapshotOutput {
    static func outputDirectory() -> URL {
        // Check both direct env var and TEST_RUNNER_ prefixed version (for xcodebuild)
        let envKeys = ["WIDGET_SNAPSHOT_DIR", "TEST_RUNNER_WIDGET_SNAPSHOT_DIR"]
        let custom = envKeys.compactMap { ProcessInfo.processInfo.environment[$0] }.first { !$0.isEmpty }

        if let custom = custom {
            let expanded = (custom as NSString).expandingTildeInPath
            let customURL = URL(fileURLWithPath: expanded, isDirectory: true)
            if expanded.hasPrefix("/") {
                return customURL
            }

            if let root = repoRootURL() {
                return root.appendingPathComponent(expanded, isDirectory: true)
            }

            return customURL
        }

        if let root = repoRootURL() {
            return root.appendingPathComponent(".context/widget-snapshots", isDirectory: true)
        }

        let fallback = ProcessInfo.processInfo.environment["SRCROOT"] ?? FileManager.default.currentDirectoryPath
        return URL(fileURLWithPath: fallback, isDirectory: true)
            .appendingPathComponent(".context/widget-snapshots", isDirectory: true)
    }

    static func writePNG(_ image: NSImage, to url: URL) throws {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw SnapshotError.encodeFailed(url.lastPathComponent)
        }

        try pngData.write(to: url, options: .atomic)
    }

    private static func repoRootURL() -> URL? {
        let environment = ProcessInfo.processInfo.environment
        let keys = ["PROJECT_DIR", "SRCROOT"]
        for key in keys {
            if let value = environment[key], !value.isEmpty {
                return URL(fileURLWithPath: value, isDirectory: true)
            }
        }

        let startingPoints: [URL] = [
            URL(fileURLWithPath: #filePath, isDirectory: false).deletingLastPathComponent(),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true),
            Bundle(for: WidgetSnapshotTests.self).bundleURL
        ]

        for start in startingPoints {
            if let root = findRepoRoot(from: start) {
                return root
            }
        }

        return nil
    }

    private static func findRepoRoot(from start: URL) -> URL? {
        var current = start
        var isDir: ObjCBool = false

        while FileManager.default.fileExists(atPath: current.path, isDirectory: &isDir), isDir.boolValue {
            let hasProject = FileManager.default.fileExists(atPath: current.appendingPathComponent("AgentUsageWidget.xcodeproj").path)
            let hasWorkspace = FileManager.default.fileExists(atPath: current.appendingPathComponent("AgentUsageWidget.xcworkspace").path)
            let hasGit = FileManager.default.fileExists(atPath: current.appendingPathComponent(".git").path)

            if hasProject || hasWorkspace || hasGit {
                return current
            }

            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                break
            }
            current = parent
        }

        return nil
    }
}

private enum SnapshotEnvironment {
    static let timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    static let locale = Locale(identifier: "en_US_POSIX")
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.timeZone = timeZone
        return calendar
    }()

    static func configureForDeterministicOutput() {
        NSTimeZone.default = timeZone
        UserDefaults.standard.set(["en_US_POSIX"], forKey: "AppleLanguages")
        UserDefaults.standard.set("en_US_POSIX", forKey: "AppleLocale")
        setenv("LC_ALL", "en_US_POSIX", 1)
        setenv("LANG", "en_US_POSIX", 1)
    }
}

private enum SnapshotError: Error {
    case renderFailed(String)
    case encodeFailed(String)
}
