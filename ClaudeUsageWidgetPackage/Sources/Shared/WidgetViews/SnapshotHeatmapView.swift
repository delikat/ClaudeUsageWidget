import Foundation
import SwiftUI

public extension Color {
    static let snapshotHeatmapLevel0 = Color(white: 0.2)
    static let snapshotHeatmapLevel1 = Color(red: 0.0, green: 0.4, blue: 0.2)
    static let snapshotHeatmapLevel2 = Color(red: 0.0, green: 0.5, blue: 0.3)
    static let snapshotHeatmapLevel3 = Color(red: 0.0, green: 0.65, blue: 0.4)
    static let snapshotHeatmapLevel4 = Color(red: 0.0, green: 0.8, blue: 0.5)
}

private struct SnapshotHeatmapCell: View {
    let tokens: Int
    let maxTokens: Int

    private var intensity: Double {
        guard maxTokens > 0 else { return 0 }
        return Double(tokens) / Double(maxTokens)
    }

    private var cellColor: Color {
        if tokens == 0 {
            return .snapshotHeatmapLevel0
        }
        switch intensity {
        case 0..<0.25:
            return .snapshotHeatmapLevel1
        case 0.25..<0.5:
            return .snapshotHeatmapLevel2
        case 0.5..<0.75:
            return .snapshotHeatmapLevel3
        default:
            return .snapshotHeatmapLevel4
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(cellColor)
    }
}

private struct SnapshotHeatmapGridView: View {
    let history: UsageHistory
    let referenceDate: Date
    let weeksToShow: Int = 5
    let daysPerWeek: Int = 7

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func dateString(for dayOffset: Int) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: referenceDate) else {
            return ""
        }
        return formatter.string(from: date)
    }

    private var todayWeekdayIndex: Int {
        calendar.component(.weekday, from: referenceDate) - 1
    }

    private var gridData: [[DailyUsage?]] {
        var weeks: [[DailyUsage?]] = []

        for weekIndex in 0..<weeksToShow {
            var week: [DailyUsage?] = []
            for dayOfWeek in 0..<daysPerWeek {
                let daysAgo = (weeksToShow - 1 - weekIndex) * 7 + (todayWeekdayIndex - dayOfWeek)

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

        HStack(spacing: 3) {
            VStack(spacing: 3) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .frame(width: 12, height: 12)
                }
            }

            HStack(spacing: 3) {
                ForEach(0..<weeksToShow, id: \.self) { weekIndex in
                    VStack(spacing: 3) {
                        ForEach(0..<daysPerWeek, id: \.self) { dayIndex in
                            let usage = gridData[weekIndex][dayIndex]
                            SnapshotHeatmapCell(
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

private struct SnapshotHeatmapLegend: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("Less")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.tertiary)

            ForEach([
                Color.snapshotHeatmapLevel0,
                .snapshotHeatmapLevel1,
                .snapshotHeatmapLevel2,
                .snapshotHeatmapLevel3,
                .snapshotHeatmapLevel4
            ], id: \.self) { color in
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

private struct SnapshotHeatmapStats: View {
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

public struct SnapshotLargeHeatmapWidgetView: View {
    public let history: UsageHistory
    public let referenceDate: Date

    public init(history: UsageHistory, referenceDate: Date) {
        self.history = history
        self.referenceDate = referenceDate
    }

    public var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Usage Heatmap")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("Last 35 days")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
            }

            SnapshotHeatmapGridView(history: history, referenceDate: referenceDate)
                .frame(maxWidth: .infinity)

            Spacer()

            SnapshotHeatmapStats(history: history)

            SnapshotHeatmapLegend()
        }
        .dsCardStyle(padding: 16)
        .padding(6)
    }
}
