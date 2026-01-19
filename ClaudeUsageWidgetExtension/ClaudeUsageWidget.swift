import WidgetKit
import SwiftUI
import AppIntents
import Shared

// MARK: - Pastel Colors (More Saturated)

extension Color {
    static let pastelMint = Color(red: 0.3, green: 0.8, blue: 0.6)
    static let pastelAmber = Color(red: 0.95, green: 0.65, blue: 0.3)
    static let pastelCoral = Color(red: 0.95, green: 0.4, blue: 0.4)
    static let progressTrack = Color.white.opacity(0.3)
}

// MARK: - Capsule Progress Bar

struct CapsuleProgressBar: View {
    let value: Double
    let color: Color
    private let barHeight: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.progressTrack)
                    .frame(height: barHeight)
                Capsule()
                    .fill(color)
                    .frame(width: geometry.size.width * CGFloat(min(max(0, value), 100) / 100), height: barHeight)
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
                .stroke(Color.progressTrack, lineWidth: lineWidth)

            // Filled arc
            Circle()
                .trim(from: 0, to: CGFloat(min(value, 100)) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Percentage text
            Text("\(Int(value))%")
                .font(.system(.title2, design: .rounded, weight: .semibold))
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
            VStack(spacing: 10) {
                HStack {
                    Text("5h Usage")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    RefreshButton()
                }

                UsageGauge(value: entry.usage.fiveHourUsage)

                if let resetAt = entry.usage.fiveHourResetAt {
                    Text("Resets \(resetAt, style: .relative)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
        }
    }
}

struct MediumWidgetView: View {
    let entry: UsageEntry

    var body: some View {
        if entry.usage.error != nil {
            ErrorView(error: entry.usage.error)
        } else {
            VStack(spacing: 6) {
                HStack {
                    Spacer()
                    RefreshButton()
                }
                .padding(.trailing, 4)

                HStack(spacing: 24) {
                    UsageColumn(
                        title: "5 Hour",
                        value: entry.usage.fiveHourUsage,
                        resetAt: entry.usage.fiveHourResetAt
                    )

                    Divider()

                    UsageColumn(
                        title: "7 Day",
                        value: entry.usage.sevenDayUsage,
                        resetAt: entry.usage.sevenDayResetAt
                    )
                }
            }
            .padding(14)
        }
    }
}

struct UsageColumn: View {
    let title: String
    let value: Double
    let resetAt: Date?

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(.secondary)

            UsageGauge(value: value)

            if let resetAt = resetAt {
                Text("Resets \(resetAt, style: .relative)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

struct UsageGauge: View {
    let value: Double

    var color: Color {
        switch value {
        case 0..<50:
            return .pastelMint
        case 50..<80:
            return .pastelAmber
        default:
            return .pastelCoral
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("\(Int(value))%")
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(color)

            CapsuleProgressBar(value: value, color: color)
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
                .font(.title)
                .foregroundStyle(.orange)

            Text(title)
                .font(.caption.bold())

            Text(message)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
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
                    Text("5h Usage")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    RefreshButton()
                }

                CircularRingGauge(
                    value: entry.usage.fiveHourUsage,
                    color: usageColor(for: entry.usage.fiveHourUsage),
                    lineWidth: 10
                )

                if let resetAt = entry.usage.fiveHourResetAt {
                    Text("Resets \(resetAt, style: .relative)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
        }
    }
}

struct MediumGaugeWidgetView: View {
    let entry: UsageEntry

    var body: some View {
        if entry.usage.error != nil {
            ErrorView(error: entry.usage.error)
        } else {
            HStack(spacing: 20) {
                GaugeColumn(
                    title: "5 Hour",
                    value: entry.usage.fiveHourUsage,
                    resetAt: entry.usage.fiveHourResetAt
                )

                Divider()

                GaugeColumn(
                    title: "7 Day",
                    value: entry.usage.sevenDayUsage,
                    resetAt: entry.usage.sevenDayResetAt
                )
            }
            .padding(14)
            .overlay(alignment: .topTrailing) {
                RefreshButton()
                    .padding(10)
            }
        }
    }
}

struct GaugeColumn: View {
    let title: String
    let value: Double
    let resetAt: Date?

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(.secondary)

            CircularRingGauge(
                value: value,
                color: usageColor(for: value),
                lineWidth: 10
            )

            if let resetAt = resetAt {
                Text("Resets \(resetAt, style: .relative)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

// Helper function for color
func usageColor(for value: Double) -> Color {
    switch value {
    case 0..<50:
        return .pastelMint
    case 50..<80:
        return .pastelAmber
    default:
        return .pastelCoral
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
