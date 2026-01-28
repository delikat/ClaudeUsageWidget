import WidgetKit
import SwiftUI
import AppIntents
import Shared

// MARK: - Legacy Color Extensions (for heatmap compatibility)

extension Color {
    // Usage status colors (legacy, use dsUsageColor() instead)
    static let usageGreen = Color.dsGreen
    static let usageOrange = Color.dsOrange
    static let usageRed = Color.dsRed

    // Dark theme colors (legacy, for heatmap widget)
    static let widgetBackground = Color(white: 0.12)
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.6)
    static let tertiaryText = Color.white.opacity(0.4)
    static let trackBackground = Color.dsTrackBackground
}

// MARK: - Formatting Helpers

private func formattedCost(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "USD"
    formatter.maximumFractionDigits = 2
    formatter.minimumFractionDigits = 2
    formatter.positiveFormat = formatter.positiveFormat.replacingOccurrences(
        of: "\\s*¤\\s*",
        with: "¤",
        options: .regularExpression
    )
    formatter.negativeFormat = formatter.negativeFormat.replacingOccurrences(
        of: "\\s*¤\\s*",
        with: "¤",
        options: .regularExpression
    )
    return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
}

private func formattedTokens(_ value: Int) -> String {
    guard value >= 1_000 else { return "\(value)" }
    let divisor: Double
    let suffix: String
    if value >= 1_000_000 {
        divisor = 1_000_000
        suffix = "m"
    } else {
        divisor = 1_000
        suffix = "k"
    }
    let scaled = Double(value) / divisor
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 1
    formatter.roundingMode = .down
    let formatted = formatter.string(from: NSNumber(value: scaled)) ?? String(format: "%.1f", scaled)
    return "\(formatted)\(suffix)"
}

private func resetRelativeText(_ date: Date) -> Text {
    Text("Resets ") + Text(date, format: .relative(presentation: .numeric, unitsStyle: .abbreviated))
}

private func monthTitle(for identifier: String) -> String {
    guard let date = MonthlyStats.monthDate(from: identifier) else { return identifier }
    let formatter = DateFormatter()
    formatter.dateFormat = "LLLL yyyy"
    return formatter.string(from: date)
}

private func shortModelName(_ model: String) -> String {
    let trimmed = model.replacingOccurrences(of: "claude-", with: "")
    return trimmed.isEmpty ? model : trimmed
}

private struct UpdatedAtView: View {
    let date: Date

    var body: some View {
        Text("Updated \(WidgetUpdateTimeFormatter.formatUpdateTime(since: date))")
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

private struct AdaptiveRingGauge: View {
    let value: Double
    let ringColor: Color
    let valueColor: Color

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let metrics = dsRingMetrics(for: size)
            DSCircularRingGauge(
                value: value,
                color: ringColor,
                lineWidth: metrics.lineWidth,
                percentageFontSize: metrics.percentageFontSize,
                valueColor: valueColor
            )
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Timeline Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(date: Date(), usage: .placeholder, monthly: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        let usage = UsageCacheManager.shared.read() ?? .placeholder
        let monthly = MonthlyUsageCacheManager.claude.read() ?? .placeholder
        completion(UsageEntry(date: Date(), usage: usage, monthly: monthly))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        let usage = UsageCacheManager.shared.read() ?? .noCredentialsError
        let monthly = MonthlyUsageCacheManager.claude.read() ?? .noData
        let entry = UsageEntry(date: Date(), usage: usage, monthly: monthly)
        // Refresh widget every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Timeline Entry

struct UsageEntry: TimelineEntry {
    let date: Date
    let usage: CachedUsage
    let monthly: CachedMonthlyUsage
}

// MARK: - Widget Views

struct SmallWidgetView: View {
    let entry: UsageEntry

    var body: some View {
        if entry.usage.error != nil {
            ErrorView(error: entry.usage.error)
        } else {
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("5 Hour")
                            .font(.system(size: 13, weight: .semibold))
                        Text(entry.usage.planTitle ?? "Usage Limit")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer()
                    Text("\(Int(entry.usage.fiveHourUsage))%")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(dsUsageColor(for: entry.usage.fiveHourUsage))
                        .monospacedDigit()
                }

                DSProgressBar(
                    value: entry.usage.fiveHourUsage,
                    color: dsUsageColor(for: entry.usage.fiveHourUsage)
                )

                HStack {
                    RefreshButton()
                    Spacer()
                    if let resetAt = entry.usage.fiveHourResetAt {
                        resetRelativeText(resetAt)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                UpdatedAtView(date: entry.usage.fetchedAt)
            }
            .dsCardStyle()
            .padding(6)
        }
    }
}

struct MediumWidgetView: View {
    let entry: UsageEntry

    var body: some View {
        if entry.usage.error != nil {
            ErrorView(error: entry.usage.error)
        } else {
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    UsageCard(
                        title: "5 Hour",
                        subtitle: entry.usage.planTitle ?? "Usage Limit",
                        value: entry.usage.fiveHourUsage,
                        resetAt: entry.usage.fiveHourResetAt,
                        showRefresh: true,
                        updatedAt: nil
                    )

                    UsageCard(
                        title: "7 Day",
                        subtitle: entry.usage.planTitle ?? "Usage Limit",
                        value: entry.usage.sevenDayUsage,
                        resetAt: entry.usage.sevenDayResetAt,
                        showRefresh: false,
                        updatedAt: nil
                    )
                }
                UpdatedAtView(date: entry.usage.fetchedAt)
            }
            .padding(6)
        }
    }
}

struct UsageCard: View {
    let title: String
    let subtitle: String
    let value: Double
    let resetAt: Date?
    let showRefresh: Bool
    let updatedAt: Date?

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(value))%")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(dsUsageColor(for: value))
                    .monospacedDigit()
            }

            DSProgressBar(value: value, color: dsUsageColor(for: value))

            HStack {
                if showRefresh {
                    RefreshButton()
                }
                Spacer()
                if let resetAt = resetAt {
                    resetRelativeText(resetAt)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            if let updatedAt = updatedAt {
                UpdatedAtView(date: updatedAt)
            }
        }
        .dsCardStyle()
    }
}

struct LargeWidgetView: View {
    let entry: UsageEntry

    private var monthStats: MonthlyStats? {
        let currentMonth = MonthlyStats.monthIdentifier(for: Date())
        if let current = entry.monthly.months.first(where: { $0.month == currentMonth }) {
            return current
        }
        return entry.monthly.months.sorted { $0.month > $1.month }.first
    }

    var body: some View {
        if entry.monthly.error != nil || monthStats == nil {
            MonthlyErrorView(error: entry.monthly.error)
        } else if let stats = monthStats {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(monthTitle(for: stats.month))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("Monthly Usage")
                            .font(.system(size: 14, weight: .bold))
                    }
                    Spacer()
                    MonthlyRefreshButton()
                }

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(formattedCost(stats.totalCost))
                            .font(.system(size: 30, weight: .bold, design: .monospaced))
                            .monospacedDigit()

                        TokenBreakdownView(stats: stats)

                        ModelSummaryView(models: stats.models)
                    }

                    Spacer()

                    MiniGaugeStack(entry: entry)
                }

                UpdatedAtView(date: entry.monthly.fetchedAt)
                    .padding(.top, -2)
            }
            .dsCardStyle(padding: 16)
            .padding(6)
        }
    }
}

private struct TokenBreakdownView: View {
    let stats: MonthlyStats

    var body: some View {
        HStack(spacing: 12) {
            TokenStat(label: "Input", value: stats.inputTokens)
            TokenStat(label: "Output", value: stats.outputTokens)
            TokenStat(label: "Cache Read", value: stats.cacheReadInputTokens)
            TokenStat(label: "Cache Create", value: stats.cacheCreationInputTokens)
        }
    }
}

private struct TokenStat: View {
    let label: String
    let value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
            Text(formattedTokens(value))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .monospacedDigit()
        }
    }
}

private struct ModelSummaryView: View {
    let models: [ModelBreakdown]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Top Models")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            ForEach(models.prefix(3)) { model in
                HStack {
                    Text(shortModelName(model.model))
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                    Spacer()
                    Text(formattedCost(model.totalCost))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
    }
}

private struct MiniGaugeStack: View {
    let entry: UsageEntry

    var body: some View {
        VStack(spacing: 8) {
            MiniGauge(
                label: "5h",
                value: entry.usage.fiveHourUsage
            )
            MiniGauge(
                label: "7d",
                value: entry.usage.sevenDayUsage
            )
        }
    }
}

private struct MiniGauge: View {
    let label: String
    let value: Double

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            DSCircularRingGauge(
                value: value,
                color: dsRingColor(for: value),
                lineWidth: 6,
                percentageFontSize: 10,
                valueColor: dsUsageColor(for: value)
            )
            .frame(width: 44, height: 44)
        }
    }
}

struct ErrorView: View {
    let error: CachedUsage.CacheError?

    private var icon: String {
        switch error {
        case .networkError:
            return "wifi.slash"
        case .invalidToken:
            return "key.slash"
        case .invalidCredentialsFormat:
            return "doc.questionmark"
        default:
            return "exclamationmark.triangle.fill"
        }
    }

    private var title: String {
        switch error {
        case .networkError:
            return "Network Error"
        case .invalidToken:
            return "Token Expired"
        case .apiError:
            return "API Error"
        case .invalidCredentialsFormat:
            return "Invalid Credentials"
        default:
            return "Setup Required"
        }
    }

    private var message: String {
        switch error {
        case .networkError:
            return "Check connection"
        case .invalidToken:
            return "Re-login to Claude Code"
        case .apiError:
            return "Try again later"
        case .invalidCredentialsFormat:
            return "Re-install Claude Code"
        default:
            return "Install Claude Code"
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.dsOrange)

            Text(title)
                .font(.system(size: 13, weight: .semibold))

            Text(message)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dsCardStyle(padding: 16)
        .padding(6)
    }
}

struct MonthlyErrorView: View {
    let error: CachedMonthlyUsage.CacheError?

    private var title: String {
        switch error {
        case .readError:
            return "Monthly Data Error"
        default:
            return "No Monthly Data"
        }
    }

    private var message: String {
        switch error {
        case .readError:
            return "Check Claude logs"
        default:
            return "Run Claude Code to generate logs"
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                MonthlyRefreshButton()
            }

            Spacer()

            Image(systemName: "calendar.badge.exclamationmark")
                .font(.title2)
                .foregroundStyle(Color.dsOrange)

            Text(title)
                .font(.system(size: 13, weight: .semibold))

            Text(message)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dsCardStyle(padding: 16)
        .padding(6)
    }
}

// MARK: - Gauge Widget Views

struct SmallGaugeWidgetView: View {
    let entry: UsageEntry

    var body: some View {
        if entry.usage.error != nil {
            ErrorView(error: entry.usage.error)
        } else {
            VStack(spacing: 6) {
                HStack {
                    Text("5 Hour")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    RefreshButton()
                }

                Text(entry.usage.planTitle ?? "Usage Limit")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                AdaptiveRingGauge(
                    value: entry.usage.fiveHourUsage,
                    ringColor: dsRingColor(for: entry.usage.fiveHourUsage),
                    valueColor: dsUsageColor(for: entry.usage.fiveHourUsage)
                )
                .frame(height: 72)

                if let resetAt = entry.usage.fiveHourResetAt {
                    resetRelativeText(resetAt)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                UpdatedAtView(date: entry.usage.fetchedAt)
            }
            .dsCardStyle()
            .padding(6)
        }
    }
}

struct MediumGaugeWidgetView: View {
    let entry: UsageEntry

    var body: some View {
        if entry.usage.error != nil {
            ErrorView(error: entry.usage.error)
        } else {
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    GaugeCard(
                        title: "5 Hour",
                        subtitle: entry.usage.planTitle ?? "Usage Limit",
                        value: entry.usage.fiveHourUsage,
                        resetAt: entry.usage.fiveHourResetAt,
                        showRefresh: true,
                        updatedAt: nil
                    )

                    GaugeCard(
                        title: "7 Day",
                        subtitle: entry.usage.planTitle ?? "Usage Limit",
                        value: entry.usage.sevenDayUsage,
                        resetAt: entry.usage.sevenDayResetAt,
                        showRefresh: false,
                        updatedAt: nil
                    )
                }
                UpdatedAtView(date: entry.usage.fetchedAt)
            }
            .padding(6)
        }
    }
}

struct GaugeCard: View {
    let title: String
    let subtitle: String
    let value: Double
    let resetAt: Date?
    let showRefresh: Bool
    let updatedAt: Date?

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if showRefresh {
                    RefreshButton()
                }
            }

            AdaptiveRingGauge(
                value: value,
                ringColor: dsRingColor(for: value),
                valueColor: dsUsageColor(for: value)
            )
            .frame(height: 72)

            if let resetAt = resetAt {
                resetRelativeText(resetAt)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            if let updatedAt = updatedAt {
                UpdatedAtView(date: updatedAt)
            }
        }
        .dsCardStyle()
    }
}

// MARK: - Gauge Widget Entry View

struct GaugeWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: UsageEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallGaugeWidgetView(entry: entry)
        case .systemMedium:
            MediumGaugeWidgetView(entry: entry)
        default:
            SmallGaugeWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Entry View

struct ClaudeWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: UsageEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Configuration

struct ClaudeWidget: Widget {
    let kind: String = "ClaudeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ClaudeWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Claude Usage")
        .description("Monitor your Claude Code API usage limits")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Gauge Widget Configuration

struct ClaudeGaugeWidget: Widget {
    let kind: String = "ClaudeGaugeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            GaugeWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Claude Usage (Gauge)")
        .description("Circular gauge showing Claude Code API usage")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Refresh Button

struct RefreshButton: View {
    var body: some View {
        Button(intent: RefreshUsageIntent()) {
            Image(systemName: "arrow.clockwise")
                .font(.caption)
        }
        .buttonStyle(.plain)
    }
}

struct MonthlyRefreshButton: View {
    var body: some View {
        Button(intent: RefreshMonthlyUsageIntent()) {
            Image(systemName: "arrow.clockwise")
                .font(.caption)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Widget Bundle

@main
struct ClaudeWidgetBundle: WidgetBundle {
    var body: some Widget {
        ClaudeWidget()
        ClaudeGaugeWidget()
        UsageHeatmapWidget()
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    ClaudeWidget()
} timeline: {
    UsageEntry(date: Date(), usage: .placeholder, monthly: .placeholder)
}

#Preview("Medium", as: .systemMedium) {
    ClaudeWidget()
} timeline: {
    UsageEntry(date: Date(), usage: .placeholder, monthly: .placeholder)
}

#Preview("Error State", as: .systemSmall) {
    ClaudeWidget()
} timeline: {
    UsageEntry(date: Date(), usage: .noCredentialsError, monthly: .noData)
}

#Preview("Gauge Small", as: .systemSmall) {
    ClaudeGaugeWidget()
} timeline: {
    UsageEntry(date: Date(), usage: .placeholder, monthly: .placeholder)
}

#Preview("Gauge Medium", as: .systemMedium) {
    ClaudeGaugeWidget()
} timeline: {
    UsageEntry(date: Date(), usage: .placeholder, monthly: .placeholder)
}

#Preview("Large", as: .systemLarge) {
    ClaudeWidget()
} timeline: {
    UsageEntry(date: Date(), usage: .placeholder, monthly: .placeholder)
}
