import WidgetKit
import SwiftUI
import Shared

// MARK: - Heatmap Colors

enum HeatmapLevel: Int, CaseIterable {
    case none = 0
    case firstQuartile = 1
    case secondQuartile = 2
    case thirdQuartile = 3
    case fourthQuartile = 4

    var lightColor: Color {
        switch self {
        case .none:
            return Color(white: 0.85)
        case .firstQuartile:
            return Color(red: 0.0, green: 0.4, blue: 0.2)
        case .secondQuartile:
            return Color(red: 0.0, green: 0.5, blue: 0.3)
        case .thirdQuartile:
            return Color(red: 0.0, green: 0.65, blue: 0.4)
        case .fourthQuartile:
            return Color(red: 0.0, green: 0.8, blue: 0.5)
        }
    }

    var darkColor: Color {
        switch self {
        case .none:
            return Color(white: 0.25)
        case .firstQuartile:
            return Color(red: 0.0, green: 0.4, blue: 0.2)
        case .secondQuartile:
            return Color(red: 0.0, green: 0.5, blue: 0.3)
        case .thirdQuartile:
            return Color(red: 0.0, green: 0.65, blue: 0.4)
        case .fourthQuartile:
            return Color(red: 0.0, green: 0.8, blue: 0.5)
        }
    }

    var accentedOpacity: Double {
        switch self {
        case .none:
            return 0.1
        case .firstQuartile:
            return 0.3
        case .secondQuartile:
            return 0.5
        case .thirdQuartile:
            return 0.7
        case .fourthQuartile:
            return 1.0
        }
    }

    @MainActor
    func color(for renderingMode: WidgetRenderingMode, colorScheme: ColorScheme) -> Color {
        if renderingMode == .accented {
            return Color.white.opacity(accentedOpacity)
        }
        return colorScheme == .dark ? darkColor : lightColor
    }
}

// MARK: - Heatmap Timeline Provider

struct HeatmapProvider: TimelineProvider {
    func placeholder(in context: Context) -> HeatmapEntry {
        HeatmapEntry(date: Date(), history: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (HeatmapEntry) -> Void) {
        let history = UsageHistoryManager.shared.read() ?? .placeholder
        completion(HeatmapEntry(date: Date(), history: history))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HeatmapEntry>) -> Void) {
        let history = UsageHistoryManager.shared.read() ?? UsageHistory()
        let entry = HeatmapEntry(date: Date(), history: history)
        // Refresh widget every hour (history updates hourly)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Heatmap Timeline Entry

struct HeatmapEntry: TimelineEntry {
    let date: Date
    let history: UsageHistory
}

// MARK: - Heatmap Cell View

struct HeatmapCell: View {
    let level: HeatmapLevel
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(level.color(for: renderingMode, colorScheme: colorScheme))
    }
}

// MARK: - Heatmap Grid View

struct HeatmapGridView: View {
    let history: UsageHistory
    let weeksToShow: Int = 5
    let daysPerWeek: Int = 7

    private var calendar: Calendar { Calendar.current }

    /// Get the date string for a given day offset from today
    private func dateString(for dayOffset: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else {
            return ""
        }
        return formatter.string(from: date)
    }

    /// Get the day of week index (0 = Sunday) for today
    private var todayWeekdayIndex: Int {
        // Calendar weekday is 1-indexed (1 = Sunday)
        return calendar.component(.weekday, from: Date()) - 1
    }

    /// Calculate the total days to show based on weeks and current day
    private var totalDays: Int {
        // Show complete weeks plus days up to today
        return weeksToShow * daysPerWeek
    }

    /// Build the grid data: array of weeks, each containing 7 days
    /// Grid goes from bottom-left (oldest) to top-right (newest)
    private var gridData: [[DailyUsage?]] {
        var weeks: [[DailyUsage?]] = []

        // We want to show 5 weeks of data ending with today
        // Rightmost column is current week, bottommost row is Sunday
        for weekIndex in 0..<weeksToShow {
            var week: [DailyUsage?] = []
            for dayOfWeek in 0..<daysPerWeek {
                // Calculate day offset from today
                // weekIndex 0 = current week, weekIndex 4 = 4 weeks ago
                // dayOfWeek 0 = Sunday, dayOfWeek 6 = Saturday
                let daysAgo = (weeksToShow - 1 - weekIndex) * 7 + (todayWeekdayIndex - dayOfWeek)

                // Skip future days
                if daysAgo < 0 {
                    week.append(nil)
                    continue
                }

                let dateStr = dateString(for: daysAgo)
                week.append(history.usage(for: dateStr))
            }
            weeks.append(week)
        }

        return weeks
    }

    private var usageThresholds: (Int, Int, Int)? {
        let values = history.entries.map(\.totalTokens).filter { $0 > 0 }.sorted()
        guard !values.isEmpty else { return nil }
        let q1 = percentile(values, percentile: 0.25)
        let q2 = percentile(values, percentile: 0.5)
        let q3 = percentile(values, percentile: 0.75)
        return (q1, q2, q3)
    }

    private func percentile(_ values: [Int], percentile: Double) -> Int {
        guard !values.isEmpty else { return 0 }
        let index = Int((Double(values.count - 1) * percentile).rounded(.down))
        return values[min(max(index, 0), values.count - 1)]
    }

    var body: some View {
        let thresholds = usageThresholds

        HStack(spacing: 3) {
            // Day labels column (Sun-Sat)
            VStack(spacing: 3) {
                let days = ["S", "M", "T", "W", "T", "F", "S"]
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .frame(width: 12, height: 12)
                }
            }

            // Heatmap grid
            HStack(spacing: 3) {
                ForEach(0..<weeksToShow, id: \.self) { weekIndex in
                    VStack(spacing: 3) {
                        ForEach(0..<daysPerWeek, id: \.self) { dayIndex in
                            let usage = gridData[weekIndex][dayIndex]
                            HeatmapCell(
                                level: level(for: usage?.totalTokens ?? 0, thresholds: thresholds)
                            )
                            .frame(width: 12, height: 12)
                        }
                    }
                }
            }
        }
    }

    private func level(for tokens: Int, thresholds: (Int, Int, Int)?) -> HeatmapLevel {
        guard tokens > 0 else { return .none }
        guard let thresholds else { return .firstQuartile }
        if tokens <= thresholds.0 { return .firstQuartile }
        if tokens <= thresholds.1 { return .secondQuartile }
        if tokens <= thresholds.2 { return .thirdQuartile }
        return .fourthQuartile
    }
}

// MARK: - Heatmap Legend

struct HeatmapLegend: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 4) {
            Text("Less")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.tertiary)

            ForEach(HeatmapLevel.allCases, id: \.self) { level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(level.color(for: renderingMode, colorScheme: colorScheme))
                    .frame(width: 10, height: 10)
            }

            Text("More")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.tertiary)
        }
    }
}

private struct UpdatedAtView: View {
    let date: Date

    var body: some View {
        Text("Updated \(WidgetUpdateTimeFormatter.formatUpdateTime(since: date))")
            .font(.system(size: 8, weight: .medium))
            .foregroundStyle(.tertiary)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

// MARK: - Stats Summary

struct HeatmapStats: View {
    let history: UsageHistory

    private var totalTokens: Int {
        history.entries.reduce(0) { $0 + $1.totalTokens }
    }

    private var claudeTokens: Int {
        history.entries.reduce(0) { $0 + $1.claudeTokens }
    }

    private var codexTokens: Int {
        history.entries.reduce(0) { $0 + $1.codexTokens }
    }

    private func formatTokens(_ tokens: Int) -> String {
        guard tokens >= 1_000 else { return "\(tokens)" }
        let divisor: Double
        let suffix: String
        if tokens >= 1_000_000 {
            divisor = 1_000_000
            suffix = "m"
        } else {
            divisor = 1_000
            suffix = "k"
        }
        let scaled = Double(tokens) / divisor
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        formatter.roundingMode = .down
        let formatted = formatter.string(from: NSNumber(value: scaled)) ?? String(format: "%.1f", scaled)
        return "\(formatted)\(suffix)"
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Claude")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(formatTokens(claudeTokens))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Codex")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(formatTokens(codexTokens))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .monospacedDigit()
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Total")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(formatTokens(totalTokens))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.dsGreen)
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Large Heatmap Widget View

struct LargeHeatmapWidgetView: View {
    let entry: HeatmapEntry

    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                Text("Usage Heatmap")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("Last 35 days")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
            }

            // Heatmap grid
            HeatmapGridView(history: entry.history)
                .frame(maxWidth: .infinity)

            Spacer()

            // Stats summary
            HeatmapStats(history: entry.history)

            // Legend
            HeatmapLegend()

            if let fetchedAt = entry.history.fetchedAt {
                UpdatedAtView(date: fetchedAt)
            }
        }
        .dsCardStyle(padding: 16)
        .padding(6)
    }
}

// MARK: - Widget Entry View

struct HeatmapWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: HeatmapEntry

    var body: some View {
        switch family {
        case .systemLarge:
            LargeHeatmapWidgetView(entry: entry)
        default:
            // Heatmap only supports large size
            VStack {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.title2)
                    .foregroundStyle(Color.dsOrange)
                Text("Use Large Size")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Heatmap Widget Configuration

struct UsageHeatmapWidget: Widget {
    let kind: String = "UsageHeatmapWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HeatmapProvider()) { entry in
            HeatmapWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Usage Heatmap")
        .description("GitHub-style heatmap showing daily Claude & Codex usage")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: - Previews

#Preview("Heatmap Large", as: .systemLarge) {
    UsageHeatmapWidget()
} timeline: {
    HeatmapEntry(date: Date(), history: .placeholder)
}
