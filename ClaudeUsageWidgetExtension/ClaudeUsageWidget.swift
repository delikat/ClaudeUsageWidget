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
        UsageEntry(date: Date(), usage: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        let usage = UsageCacheManager.shared.read() ?? .placeholder
        completion(UsageEntry(date: Date(), usage: usage))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        let usage = UsageCacheManager.shared.read() ?? .noCredentialsError
        let entry = UsageEntry(date: Date(), usage: usage)
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
        .supportedFamilies([.systemSmall, .systemMedium])
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

// MARK: - Widget Bundle

@main
struct ClaudeUsageWidgetBundle: WidgetBundle {
    var body: some Widget {
        ClaudeUsageWidget()
        ClaudeUsageGaugeWidget()
        UsageHeatmapWidget()
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    ClaudeUsageWidget()
} timeline: {
    UsageEntry(date: Date(), usage: .placeholder)
}

#Preview("Medium", as: .systemMedium) {
    ClaudeUsageWidget()
} timeline: {
    UsageEntry(date: Date(), usage: .placeholder)
}

#Preview("Error State", as: .systemSmall) {
    ClaudeUsageWidget()
} timeline: {
    UsageEntry(date: Date(), usage: .noCredentialsError)
}

#Preview("Gauge Small", as: .systemSmall) {
    ClaudeUsageGaugeWidget()
} timeline: {
    UsageEntry(date: Date(), usage: .placeholder)
}

#Preview("Gauge Medium", as: .systemMedium) {
    ClaudeUsageGaugeWidget()
} timeline: {
    UsageEntry(date: Date(), usage: .placeholder)
}
