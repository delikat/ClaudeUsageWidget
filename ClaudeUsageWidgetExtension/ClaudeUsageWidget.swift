import WidgetKit
import SwiftUI
import AppIntents
import Shared

// MARK: - Adaptive Colors

extension Color {
    // Clean system colors matching Claude Usage Tracker style
    static let usageGreen = Color.green
    static let usageOrange = Color.orange
    static let usageRed = Color.red

    // Card styling colors
    static let cardBackground = Color(nsColor: .controlBackgroundColor).opacity(0.4)
    static let cardBorder = Color.gray.opacity(0.2)
    static let trackBackground = Color.secondary.opacity(0.15)
}

// MARK: - Status Icon Helper

func statusIcon(for percentage: Double) -> String {
    switch percentage {
    case 0..<50:
        return "checkmark.circle.fill"
    case 50..<80:
        return "exclamationmark.triangle.fill"
    default:
        return "xmark.circle.fill"
    }
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

// MARK: - Card Background Modifier

struct CardBackground: ViewModifier {
    var padding: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.cardBackground)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.cardBorder, lineWidth: 1)
            )
    }
}

extension View {
    func cardStyle(padding: CGFloat = 12) -> some View {
        modifier(CardBackground(padding: padding))
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

    init(value: Double, color: Color, lineWidth: CGFloat = 8) {
        self.value = value
        self.color = color
        self.lineWidth = lineWidth
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

            // Percentage text
            Text("\(Int(value))%")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
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
                    }
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: statusIcon(for: entry.usage.fiveHourUsage))
                            .font(.system(size: 12, weight: .bold))
                        Text("\(Int(entry.usage.fiveHourUsage))%")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(usageColor(for: entry.usage.fiveHourUsage))
                }

                ProgressBar(value: entry.usage.fiveHourUsage, color: usageColor(for: entry.usage.fiveHourUsage))

                HStack {
                    RefreshButton()
                    Spacer()
                    if let resetAt = entry.usage.fiveHourResetAt {
                        Text("Resets in \(resetAt, style: .relative)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .cardStyle(padding: 16)
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
            HStack(spacing: 8) {
                UsageCard(
                    title: "5 Hour",
                    subtitle: entry.usage.planTitle ?? "Usage Limit",
                    value: entry.usage.fiveHourUsage,
                    resetAt: entry.usage.fiveHourResetAt,
                    showRefresh: true
                )

                UsageCard(
                    title: "7 Day",
                    subtitle: entry.usage.planTitle ?? "Usage Limit",
                    value: entry.usage.sevenDayUsage,
                    resetAt: entry.usage.sevenDayResetAt,
                    showRefresh: false
                )
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
                HStack(spacing: 3) {
                    Image(systemName: statusIcon(for: value))
                        .font(.system(size: 12, weight: .bold))
                    Text("\(Int(value))%")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(usageColor(for: value))
            }

            ProgressBar(value: value, color: usageColor(for: value))

            HStack {
                if showRefresh {
                    RefreshButton()
                }
                Spacer()
                if let resetAt = resetAt {
                    Text("Resets in \(resetAt, style: .relative)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .cardStyle()
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
                .foregroundStyle(Color.usageOrange)

            Text(title)
                .font(.system(size: 13, weight: .semibold))

            Text(message)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cardStyle(padding: 16)
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
                    VStack(alignment: .leading, spacing: 2) {
                        Text("5 Hour")
                            .font(.system(size: 13, weight: .semibold))
                        Text(entry.usage.planTitle ?? "Usage Limit")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    RefreshButton()
                }

                CircularRingGauge(
                    value: entry.usage.fiveHourUsage,
                    color: usageColor(for: entry.usage.fiveHourUsage),
                    lineWidth: 8
                )

                if let resetAt = entry.usage.fiveHourResetAt {
                    HStack {
                        Spacer()
                        Text("Resets in \(resetAt, style: .relative)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .cardStyle(padding: 16)
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
            HStack(spacing: 8) {
                GaugeCard(
                    title: "5 Hour",
                    subtitle: entry.usage.planTitle ?? "Usage Limit",
                    value: entry.usage.fiveHourUsage,
                    resetAt: entry.usage.fiveHourResetAt,
                    showRefresh: true
                )

                GaugeCard(
                    title: "7 Day",
                    subtitle: entry.usage.planTitle ?? "Usage Limit",
                    value: entry.usage.sevenDayUsage,
                    resetAt: entry.usage.sevenDayResetAt,
                    showRefresh: false
                )
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

            CircularRingGauge(
                value: value,
                color: usageColor(for: value),
                lineWidth: 8
            )

            if let resetAt = resetAt {
                HStack {
                    Spacer()
                    Text("Resets in \(resetAt, style: .relative)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .cardStyle()
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
                .containerBackground(.fill.tertiary, for: .widget)
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
