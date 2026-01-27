import WidgetKit
import SwiftUI
import AppIntents
import Shared

// MARK: - Dark Theme Colors

extension Color {
    // Usage status colors
    static let usageGreen = Color.green
    static let usageOrange = Color.orange
    static let usageRed = Color.red

    // Dark theme colors
    static let widgetBackground = Color(white: 0.12)
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.6)
    static let tertiaryText = Color.white.opacity(0.4)
    static let trackBackground = Color.white.opacity(0.15)
}

// MARK: - Usage Color Helper

func usageColor(for value: Double) -> Color {
    switch value {
    case 0..<50:
        return .usageGreen
    case 50..<80:
        return .usageOrange
    default:
        return .usageRed
    }
}

// MARK: - Formatting Helpers

private func formattedCost(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "USD"
    formatter.maximumFractionDigits = 2
    formatter.minimumFractionDigits = 2
    return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
}

private func formattedTokens(_ value: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
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

// MARK: - Text Helpers

private struct PlanTitleText: View {
    let title: String
    let baseSize: CGFloat

    init(_ title: String, baseSize: CGFloat = 9) {
        self.title = title
        self.baseSize = baseSize
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            Text(title)
                .font(.system(size: baseSize, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.9)
            Text(title)
                .font(.system(size: max(baseSize - 1, 8), weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.9)
        }
        .foregroundStyle(Color.secondaryText)
    }
}

private struct ResetTimeText: View {
    let prefix: String
    let date: Date
    let baseSize: CGFloat

    init(prefix: String = "Resets in", date: Date, baseSize: CGFloat = 9) {
        self.prefix = prefix
        self.date = date
        self.baseSize = baseSize
    }

    private func textContent(size: CGFloat) -> some View {
        (Text("\(prefix) ") + Text(date, style: .relative))
            .font(.system(size: size, weight: .medium))
            .lineLimit(1)
            .truncationMode(.tail)
            .minimumScaleFactor(0.9)
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            textContent(size: baseSize)
            textContent(size: max(baseSize - 1, 8))
        }
        .foregroundStyle(Color.tertiaryText)
    }
}

// MARK: - Progress Bar

struct ProgressBar: View {
    let value: Double
    let color: Color
    private let barHeight: CGFloat = 8
    private let cornerRadius: CGFloat = 4

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.trackBackground)
                    .frame(height: barHeight)
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * CGFloat(min(max(0, value), 100) / 100), height: barHeight)
                    .animation(.easeInOut(duration: 0.8), value: value)
            }
        }
        .frame(height: barHeight)
    }
}

// MARK: - Circular Ring Gauge

struct CircularRingGauge: View {
    let value: Double
    let color: Color
    let lineWidth: CGFloat
    let percentageFontSize: CGFloat

    init(value: Double, color: Color, lineWidth: CGFloat = 12, percentageFontSize: CGFloat = 20) {
        self.value = value
        self.color = color
        self.lineWidth = lineWidth
        self.percentageFontSize = percentageFontSize
    }

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(Color.trackBackground, lineWidth: lineWidth)

            // Filled arc
            Circle()
                .trim(from: 0, to: CGFloat(min(value, 100)) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.8), value: value)

            // Percentage text (white, not colored)
            Text("\(Int(value))%")
                .font(.system(size: percentageFontSize, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.primaryText)
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
    private var planTitle: String { entry.usage.planTitle ?? "Usage Limit" }

    var body: some View {
        if entry.usage.error != nil {
            ErrorView(error: entry.usage.error)
        } else {
            VStack(spacing: 6) {
                // Header row: label, percentage, refresh
                HStack {
                    Text("5h")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.primaryText)
                    Text("\(Int(entry.usage.fiveHourUsage))%")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(usageColor(for: entry.usage.fiveHourUsage))
                        .lineLimit(1)
                        .fixedSize()
                    Spacer()
                    RefreshButton()
                }

                // Progress bar
                ProgressBar(value: entry.usage.fiveHourUsage, color: usageColor(for: entry.usage.fiveHourUsage))

                // Plan subtitle
                PlanTitleText(planTitle)

                // Reset time
                if let resetAt = entry.usage.fiveHourResetAt {
                    ResetTimeText(prefix: "Resets in", date: resetAt)
                }
            }
            .padding(12)
        }
    }
}

struct MediumWidgetView: View {
    let entry: UsageEntry
    private var planTitle: String { entry.usage.planTitle ?? "Usage Limit" }

    var body: some View {
        if entry.usage.error != nil {
            ErrorView(error: entry.usage.error)
        } else {
            VStack(spacing: 8) {
                // Header row with refresh button
                HStack {
                    Spacer()
                    RefreshButton()
                }

                // Two progress bars side by side
                HStack(spacing: 16) {
                    // 5 Hour usage
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("5h")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.primaryText)
                            Text("\(Int(entry.usage.fiveHourUsage))%")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(usageColor(for: entry.usage.fiveHourUsage))
                                .lineLimit(1)
                                .fixedSize()
                        }
                        ProgressBar(value: entry.usage.fiveHourUsage, color: usageColor(for: entry.usage.fiveHourUsage))
                        if let resetAt = entry.usage.fiveHourResetAt {
                            ResetTimeText(prefix: "in", date: resetAt)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // 1 Week usage
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("1w")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.primaryText)
                            Text("\(Int(entry.usage.sevenDayUsage))%")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(usageColor(for: entry.usage.sevenDayUsage))
                                .lineLimit(1)
                                .fixedSize()
                        }
                        ProgressBar(value: entry.usage.sevenDayUsage, color: usageColor(for: entry.usage.sevenDayUsage))
                        if let resetAt = entry.usage.sevenDayResetAt {
                            ResetTimeText(prefix: "in", date: resetAt)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                // Plan subtitle centered
                PlanTitleText(planTitle)
            }
            .padding(12)
        }
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
                            .foregroundStyle(Color.secondaryText)
                        Text("Monthly Usage")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.primaryText)
                    }
                    Spacer()
                    MonthlyRefreshButton()
                }

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(formattedCost(stats.totalCost))
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.primaryText)

                        TokenBreakdownView(stats: stats)

                        ModelSummaryView(models: stats.models)
                    }

                    Spacer()

                    MiniGaugeStack(entry: entry)
                }
            }
            .padding(12)
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
                .foregroundStyle(Color.tertiaryText)
            Text(formattedTokens(value))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.primaryText)
        }
    }
}

private struct ModelSummaryView: View {
    let models: [ModelBreakdown]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Top Models")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.secondaryText)
            ForEach(models.prefix(3)) { model in
                HStack {
                    Text(shortModelName(model.model))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.primaryText)
                        .lineLimit(1)
                    Spacer()
                    Text(formattedCost(model.totalCost))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.secondaryText)
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
                label: "1w",
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
                .foregroundStyle(Color.secondaryText)
            CircularRingGauge(
                value: value,
                color: usageColor(for: value),
                lineWidth: 6,
                percentageFontSize: 10
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
            HStack {
                Spacer()
                RefreshButton()
            }

            Spacer()

            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.usageOrange)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.primaryText)

            Text(message)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.secondaryText)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
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
                .foregroundStyle(Color.usageOrange)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.primaryText)

            Text(message)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.secondaryText)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
    }
}

// MARK: - Gauge Widget Views

struct SmallGaugeWidgetView: View {
    let entry: UsageEntry
    private var planTitle: String { entry.usage.planTitle ?? "Usage Limit" }

    var body: some View {
        if entry.usage.error != nil {
            ErrorView(error: entry.usage.error)
        } else {
            VStack(spacing: 4) {
                // Refresh button top-right
                HStack {
                    Spacer()
                    RefreshButton()
                }

                // Label above gauge
                Text("5h")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.primaryText)

                // Circular gauge
                CircularRingGauge(
                    value: entry.usage.fiveHourUsage,
                    color: usageColor(for: entry.usage.fiveHourUsage),
                    lineWidth: 10,
                    percentageFontSize: 18
                )

                // Plan subtitle
                PlanTitleText(planTitle)

                // Reset time
                if let resetAt = entry.usage.fiveHourResetAt {
                    ResetTimeText(prefix: "Resets in", date: resetAt)
                }
            }
            .padding(12)
        }
    }
}

struct MediumGaugeWidgetView: View {
    let entry: UsageEntry
    private var planTitle: String { entry.usage.planTitle ?? "Usage Limit" }

    var body: some View {
        if entry.usage.error != nil {
            ErrorView(error: entry.usage.error)
        } else {
            VStack(spacing: 4) {
                // Header: Plan subtitle + refresh button
                HStack {
                    PlanTitleText(planTitle, baseSize: 10)
                    Spacer()
                    RefreshButton()
                }

                // Two gauges side by side
                HStack(spacing: 24) {
                    // 5 Hour gauge
                    VStack(spacing: 4) {
                        Text("5h")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.primaryText)
                        CircularRingGauge(
                            value: entry.usage.fiveHourUsage,
                            color: usageColor(for: entry.usage.fiveHourUsage),
                            lineWidth: 10,
                            percentageFontSize: 18
                        )
                        if let resetAt = entry.usage.fiveHourResetAt {
                            ResetTimeText(prefix: "in", date: resetAt)
                        }
                    }

                    // 1 Week gauge
                    VStack(spacing: 4) {
                        Text("1w")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.primaryText)
                        CircularRingGauge(
                            value: entry.usage.sevenDayUsage,
                            color: usageColor(for: entry.usage.sevenDayUsage),
                            lineWidth: 10,
                            percentageFontSize: 18
                        )
                        if let resetAt = entry.usage.sevenDayResetAt {
                            ResetTimeText(prefix: "in", date: resetAt)
                        }
                    }
                }
            }
            .padding(12)
        }
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

struct ClaudeUsageWidgetEntryView: View {
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

struct ClaudeUsageWidget: Widget {
    let kind: String = "ClaudeUsageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ClaudeUsageWidgetEntryView(entry: entry)
                .containerBackground(Color.widgetBackground, for: .widget)
        }
        .configurationDisplayName("Claude Usage")
        .description("Monitor your Claude Code API usage limits")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Gauge Widget Configuration

struct ClaudeUsageGaugeWidget: Widget {
    let kind: String = "ClaudeUsageGaugeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            GaugeWidgetEntryView(entry: entry)
                .containerBackground(Color.widgetBackground, for: .widget)
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
                .font(.system(size: 10))
                .foregroundStyle(Color.secondaryText)
        }
        .buttonStyle(.plain)
    }
}

struct MonthlyRefreshButton: View {
    var body: some View {
        Button(intent: RefreshMonthlyUsageIntent()) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 10))
                .foregroundStyle(Color.secondaryText)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Widget Bundle

@main
struct ClaudeUsageWidgetBundle: WidgetBundle {
    var body: some Widget {
        ClaudeUsageWidget()
        ClaudeUsageGaugeWidget()
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    ClaudeUsageWidget()
} timeline: {
    UsageEntry(date: Date(), usage: .placeholder, monthly: .placeholder)
}

#Preview("Medium", as: .systemMedium) {
    ClaudeUsageWidget()
} timeline: {
    UsageEntry(date: Date(), usage: .placeholder, monthly: .placeholder)
}

#Preview("Error State", as: .systemSmall) {
    ClaudeUsageWidget()
} timeline: {
    UsageEntry(date: Date(), usage: .noCredentialsError, monthly: .noData)
}

#Preview("Gauge Small", as: .systemSmall) {
    ClaudeUsageGaugeWidget()
} timeline: {
    UsageEntry(date: Date(), usage: .placeholder, monthly: .placeholder)
}

#Preview("Gauge Medium", as: .systemMedium) {
    ClaudeUsageGaugeWidget()
} timeline: {
    UsageEntry(date: Date(), usage: .placeholder, monthly: .placeholder)
}

#Preview("Large", as: .systemLarge) {
    ClaudeUsageWidget()
} timeline: {
    UsageEntry(date: Date(), usage: .placeholder, monthly: .placeholder)
}
