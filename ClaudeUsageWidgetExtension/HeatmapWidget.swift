import WidgetKit
import SwiftUI
import Shared

// MARK: - Heatmap Colors

extension Color {
    // Heatmap intensity colors (light to dark green)
    static let heatmapLevel0 = Color(white: 0.2)  // No activity - dark gray
    static let heatmapLevel1 = Color(red: 0.0, green: 0.4, blue: 0.2)
    static let heatmapLevel2 = Color(red: 0.0, green: 0.5, blue: 0.3)
    static let heatmapLevel3 = Color(red: 0.0, green: 0.65, blue: 0.4)
    static let heatmapLevel4 = Color(red: 0.0, green: 0.8, blue: 0.5)
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
    let tokens: Int
    let maxTokens: Int

    private var intensity: Double {
        guard maxTokens > 0 else { return 0 }
        return Double(tokens) / Double(maxTokens)
    }

    private var cellColor: Color {
        if tokens == 0 {
            return .heatmapLevel0
        }
        switch intensity {
        case 0..<0.25:
            return .heatmapLevel1
        case 0.25..<0.5:
            return .heatmapLevel2
        case 0.5..<0.75:
            return .heatmapLevel3
        default:
            return .heatmapLevel4
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(cellColor)
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

    var body: some View {
        let maxTokens = history.maxDailyTokens

        let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

        HStack(spacing: 3) {
            // Day labels column (Sun-Sat)
            VStack(spacing: 3) {
                ForEach(dayLabels.indices, id: \.self) { index in
                    Text(dayLabels[index])
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
                                tokens: usage?.totalTokens ?? 0,
                                maxTokens: maxTokens
                            )
                            .frame(width: 12, height: 12)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Heatmap Legend

struct HeatmapLegend: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("Less")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.tertiary)

            ForEach([Color.heatmapLevel0, .heatmapLevel1, .heatmapLevel2, .heatmapLevel3, .heatmapLevel4], id: \.self) { color in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 10, height: 10)
            }

            Text("More")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.tertiary)
        }
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
        if tokens >= 1_000_000 {
            return String(format: "%.1fM", Double(tokens) / 1_000_000)
        } else if tokens >= 1_000 {
            return String(format: "%.0fK", Double(tokens) / 1_000)
        }
        return "\(tokens)"
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Claude")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(formatTokens(claudeTokens))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Codex")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(formatTokens(codexTokens))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Total")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(formatTokens(totalTokens))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.dsGreen)
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
