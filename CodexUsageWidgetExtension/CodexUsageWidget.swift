import WidgetKit
import SwiftUI
import AppIntents
import Shared

// MARK: - Legacy Color Aliases (for backwards compatibility)

extension Color {
    // Clean system colors matching shared design system
    static let codexGreen = Color.dsGreen
    static let codexOrange = Color.dsOrange
    static let codexRed = Color.dsRed

    // Card styling colors
    static let codexCardBackground = Color.dsCardBackground
    static let codexCardBorder = Color.dsCardBorder
    static let codexTrackBackground = Color.dsTrackBackground
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
    if value >= 1_000_000 {
        return String(format: "%.1fm", Double(value) / 1_000_000)
    } else if value >= 1_000 {
        return String(format: "%.0fk", Double(value) / 1_000)
    }
    return "\(value)"
}

private func monthTitle(for identifier: String) -> String {
    guard let date = MonthlyStats.monthDate(from: identifier) else { return identifier }
    let formatter = DateFormatter()
    formatter.dateFormat = "LLLL yyyy"
    return formatter.string(from: date)
}

private func shortModelName(_ model: String) -> String {
    let trimmed = model
        .replacingOccurrences(of: "gpt-", with: "")
        .replacingOccurrences(of: "o1-", with: "o1-")
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

struct CodexProvider: TimelineProvider {
    func placeholder(in context: Context) -> CodexUsageEntry {
        CodexUsageEntry(date: Date(), usage: .placeholder, monthly: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (CodexUsageEntry) -> Void) {
        let usage = UsageCacheManager.codex.read() ?? .placeholder
        let monthly = MonthlyUsageCacheManager.codex.read() ?? .placeholder
        completion(CodexUsageEntry(date: Date(), usage: usage, monthly: monthly))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CodexUsageEntry>) -> Void) {
        let usage = UsageCacheManager.codex.read() ?? .noCredentialsError
        let monthly = MonthlyUsageCacheManager.codex.read() ?? .noData
        let entry = CodexUsageEntry(date: Date(), usage: usage, monthly: monthly)
        // Refresh widget every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Timeline Entry

struct CodexUsageEntry: TimelineEntry {
    let date: Date
    let usage: CachedUsage
    let monthly: CachedMonthlyUsage
}

// MARK: - Widget Views

struct CodexSmallWidgetView: View {
    let entry: CodexUsageEntry

    var body: some View {
        if entry.usage.error != nil {
            CodexErrorView(error: entry.usage.error)
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

                DSProgressBar(value: entry.usage.fiveHourUsage, color: dsUsageColor(for: entry.usage.fiveHourUsage))

                HStack {
                    CodexRefreshButton()
                    Spacer()
                    if let resetAt = entry.usage.fiveHourResetAt {
                        Text("Resets in \(ShortRelativeTimeFormatter.format(until: resetAt))")
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

struct CodexMediumWidgetView: View {
    let entry: CodexUsageEntry

    var body: some View {
        if entry.usage.error != nil {
            CodexErrorView(error: entry.usage.error)
        } else {
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    CodexUsageCard(
                        title: "5 Hour",
                        subtitle: entry.usage.planTitle ?? "Usage Limit",
                        value: entry.usage.fiveHourUsage,
                        resetAt: entry.usage.fiveHourResetAt,
                        showRefresh: true,
                        updatedAt: nil
                    )

                    CodexUsageCard(
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

struct CodexLargeWidgetView: View {
    let entry: CodexUsageEntry

    private var monthStats: MonthlyStats? {
        let currentMonth = MonthlyStats.monthIdentifier(for: Date())
        if let current = entry.monthly.months.first(where: { $0.month == currentMonth }) {
            return current
        }
        return entry.monthly.months.sorted { $0.month > $1.month }.first
    }

    var body: some View {
        if entry.monthly.error != nil || monthStats == nil {
            CodexMonthlyErrorView(error: entry.monthly.error)
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
                    CodexMonthlyRefreshButton()
                }

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(formattedCost(stats.totalCost))
                            .font(.system(size: 30, weight: .bold, design: .monospaced))
                            .monospacedDigit()

                        HStack(spacing: 12) {
                            CodexTokenStat(label: "Input", value: stats.inputTokens)
                            CodexTokenStat(label: "Output", value: stats.outputTokens)
                            CodexTokenStat(label: "Cache Read", value: stats.cacheReadInputTokens)
                            CodexTokenStat(label: "Cache Create", value: stats.cacheCreationInputTokens)
                        }

                        CodexModelSummaryView(models: stats.models)
                    }

                    Spacer()

                    CodexMiniGaugeStack(entry: entry)
                }

                UpdatedAtView(date: entry.monthly.fetchedAt)
                    .padding(.top, -2)
            }
            .dsCardStyle(padding: 16)
            .padding(6)
        }
    }
}

private struct CodexTokenStat: View {
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

private struct CodexModelSummaryView: View {
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

private struct CodexMiniGaugeStack: View {
    let entry: CodexUsageEntry

    var body: some View {
        VStack(spacing: 8) {
            CodexMiniGauge(label: "5h", value: entry.usage.fiveHourUsage)
            CodexMiniGauge(label: "7d", value: entry.usage.sevenDayUsage)
        }
    }
}

private struct CodexMiniGauge: View {
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

struct CodexUsageCard: View {
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
                    CodexRefreshButton()
                }
                Spacer()
                if let resetAt = resetAt {
                    Text("Resets in \(ShortRelativeTimeFormatter.format(until: resetAt))")
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

struct CodexErrorView: View {
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
            return "Run `chatgpt auth`"
        case .apiError:
            return "Try again later"
        case .invalidCredentialsFormat:
            return "Re-authenticate ChatGPT"
        default:
            return "Install ChatGPT CLI"
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

struct CodexMonthlyErrorView: View {
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
            return "Check Codex logs"
        default:
            return "Run Codex CLI to generate logs"
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                CodexMonthlyRefreshButton()
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

struct CodexSmallGaugeWidgetView: View {
    let entry: CodexUsageEntry

    var body: some View {
        if entry.usage.error != nil {
            CodexErrorView(error: entry.usage.error)
        } else {
            VStack(spacing: 6) {
                HStack {
                    Text("5 Hour")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    CodexRefreshButton()
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
                    Text("Resets in \(ShortRelativeTimeFormatter.format(until: resetAt))")
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

struct CodexMediumGaugeWidgetView: View {
    let entry: CodexUsageEntry

    var body: some View {
        if entry.usage.error != nil {
            CodexErrorView(error: entry.usage.error)
        } else {
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    CodexGaugeCard(
                        title: "5 Hour",
                        subtitle: entry.usage.planTitle ?? "Usage Limit",
                        value: entry.usage.fiveHourUsage,
                        resetAt: entry.usage.fiveHourResetAt,
                        showRefresh: true,
                        updatedAt: nil
                    )

                    CodexGaugeCard(
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

struct CodexGaugeCard: View {
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
                    CodexRefreshButton()
                }
            }

            AdaptiveRingGauge(
                value: value,
                ringColor: dsRingColor(for: value),
                valueColor: dsUsageColor(for: value)
            )
            .frame(height: 72)

            if let resetAt = resetAt {
                Text("Resets in \(ShortRelativeTimeFormatter.format(until: resetAt))")
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

struct CodexGaugeWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: CodexUsageEntry

    var body: some View {
        switch family {
        case .systemSmall:
            CodexSmallGaugeWidgetView(entry: entry)
        case .systemMedium:
            CodexMediumGaugeWidgetView(entry: entry)
        default:
            CodexSmallGaugeWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Entry View

struct CodexUsageWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: CodexUsageEntry

    var body: some View {
        switch family {
        case .systemSmall:
            CodexSmallWidgetView(entry: entry)
        case .systemMedium:
            CodexMediumWidgetView(entry: entry)
        case .systemLarge:
            CodexLargeWidgetView(entry: entry)
        default:
            CodexSmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Configuration

struct CodexUsageWidget: Widget {
    let kind: String = "CodexUsageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CodexProvider()) { entry in
            CodexUsageWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("ChatGPT Usage")
        .description("Monitor your ChatGPT usage limits")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Gauge Widget Configuration

struct CodexUsageGaugeWidget: Widget {
    let kind: String = "CodexUsageGaugeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CodexProvider()) { entry in
            CodexGaugeWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("ChatGPT Usage (Gauge)")
        .description("Circular gauge showing ChatGPT usage")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Refresh Button

struct CodexRefreshButton: View {
    var body: some View {
        Button(intent: RefreshCodexUsageIntent()) {
            Image(systemName: "arrow.clockwise")
                .font(.caption)
        }
        .buttonStyle(.plain)
    }
}

struct CodexMonthlyRefreshButton: View {
    var body: some View {
        Button(intent: RefreshCodexMonthlyUsageIntent()) {
            Image(systemName: "arrow.clockwise")
                .font(.caption)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Widget Bundle

@main
struct CodexUsageWidgetBundle: WidgetBundle {
    var body: some Widget {
        CodexUsageWidget()
        CodexUsageGaugeWidget()
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    CodexUsageWidget()
} timeline: {
    CodexUsageEntry(date: Date(), usage: .placeholder, monthly: .placeholder)
}

#Preview("Medium", as: .systemMedium) {
    CodexUsageWidget()
} timeline: {
    CodexUsageEntry(date: Date(), usage: .placeholder, monthly: .placeholder)
}

#Preview("Error State", as: .systemSmall) {
    CodexUsageWidget()
} timeline: {
    CodexUsageEntry(date: Date(), usage: .noCredentialsError, monthly: .noData)
}

#Preview("Gauge Small", as: .systemSmall) {
    CodexUsageGaugeWidget()
} timeline: {
    CodexUsageEntry(date: Date(), usage: .placeholder, monthly: .placeholder)
}

#Preview("Gauge Medium", as: .systemMedium) {
    CodexUsageGaugeWidget()
} timeline: {
    CodexUsageEntry(date: Date(), usage: .placeholder, monthly: .placeholder)
}

#Preview("Large", as: .systemLarge) {
    CodexUsageWidget()
} timeline: {
    CodexUsageEntry(date: Date(), usage: .placeholder, monthly: .placeholder)
}
