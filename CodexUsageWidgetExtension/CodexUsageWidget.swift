import WidgetKit
import SwiftUI
import AppIntents
import Shared

// MARK: - Adaptive Colors

extension Color {
    // Clean system colors matching Claude Usage Tracker style
    static let codexGreen = Color.green
    static let codexOrange = Color.orange
    static let codexRed = Color.red

    // Card styling colors
    static let codexCardBackground = Color(nsColor: .controlBackgroundColor).opacity(0.4)
    static let codexCardBorder = Color.gray.opacity(0.2)
    static let codexTrackBackground = Color.secondary.opacity(0.15)
}

// MARK: - Status Icon Helper

private func statusIcon(for percentage: Double) -> String {
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

private func usageColor(for value: Double) -> Color {
    switch value {
    case 0..<50:
        return .codexGreen
    case 50..<80:
        return .codexOrange
    default:
        return .codexRed
    }
}

// MARK: - Card Background Modifier

struct CodexCardBackground: ViewModifier {
    var padding: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.codexCardBackground)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.codexCardBorder, lineWidth: 1)
            )
    }
}

extension View {
    func codexCardStyle(padding: CGFloat = 12) -> some View {
        modifier(CodexCardBackground(padding: padding))
    }
}

// MARK: - Progress Bar

struct CodexProgressBar: View {
    let value: Double
    let color: Color
    private let barHeight: CGFloat = 8
    private let cornerRadius: CGFloat = 4

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.codexTrackBackground)
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

struct CodexCircularRingGauge: View {
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
                .stroke(Color.codexTrackBackground, lineWidth: lineWidth)

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

struct CodexProvider: TimelineProvider {
    func placeholder(in context: Context) -> CodexUsageEntry {
        CodexUsageEntry(date: Date(), usage: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (CodexUsageEntry) -> Void) {
        let usage = UsageCacheManager.codex.read() ?? .placeholder
        completion(CodexUsageEntry(date: Date(), usage: usage))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CodexUsageEntry>) -> Void) {
        let usage = UsageCacheManager.codex.read() ?? .noCredentialsError
        let entry = CodexUsageEntry(date: Date(), usage: usage)
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

                CodexProgressBar(value: entry.usage.fiveHourUsage, color: usageColor(for: entry.usage.fiveHourUsage))

                HStack {
                    CodexRefreshButton()
                    Spacer()
                    if let resetAt = entry.usage.fiveHourResetAt {
                        Text("Resets in \(resetAt, style: .relative)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .codexCardStyle(padding: 16)
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
            HStack(spacing: 8) {
                CodexUsageCard(
                    title: "5 Hour",
                    subtitle: entry.usage.planTitle ?? "Usage Limit",
                    value: entry.usage.fiveHourUsage,
                    resetAt: entry.usage.fiveHourResetAt,
                    showRefresh: true
                )

                CodexUsageCard(
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

struct CodexUsageCard: View {
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

            CodexProgressBar(value: value, color: usageColor(for: value))

            HStack {
                if showRefresh {
                    CodexRefreshButton()
                }
                Spacer()
                if let resetAt = resetAt {
                    Text("Resets in \(resetAt, style: .relative)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .codexCardStyle()
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
                .foregroundStyle(Color.codexOrange)

            Text(title)
                .font(.system(size: 13, weight: .semibold))

            Text(message)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .codexCardStyle(padding: 16)
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
                    VStack(alignment: .leading, spacing: 2) {
                        Text("5 Hour")
                            .font(.system(size: 13, weight: .semibold))
                        Text(entry.usage.planTitle ?? "Usage Limit")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    CodexRefreshButton()
                }

                CodexCircularRingGauge(
                    value: entry.usage.fiveHourUsage,
                    color: usageColor(for: entry.usage.fiveHourUsage),
                    lineWidth: 8
                )

                if let resetAt = entry.usage.fiveHourResetAt {
                    Text("in \(resetAt, style: .relative)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .codexCardStyle()
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
            HStack(spacing: 8) {
                CodexGaugeCard(
                    title: "5 Hour",
                    subtitle: entry.usage.planTitle ?? "Usage Limit",
                    value: entry.usage.fiveHourUsage,
                    resetAt: entry.usage.fiveHourResetAt,
                    showRefresh: true
                )

                CodexGaugeCard(
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

struct CodexGaugeCard: View {
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
                    CodexRefreshButton()
                }
            }

            CodexCircularRingGauge(
                value: value,
                color: usageColor(for: value),
                lineWidth: 8
            )

            if let resetAt = resetAt {
                Text("in \(resetAt, style: .relative)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .codexCardStyle()
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
        .description("Monitor your ChatGPT API usage limits")
        .supportedFamilies([.systemSmall, .systemMedium])
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
        .description("Circular gauge showing ChatGPT API usage")
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
    CodexUsageEntry(date: Date(), usage: .placeholder)
}

#Preview("Medium", as: .systemMedium) {
    CodexUsageWidget()
} timeline: {
    CodexUsageEntry(date: Date(), usage: .placeholder)
}

#Preview("Error State", as: .systemSmall) {
    CodexUsageWidget()
} timeline: {
    CodexUsageEntry(date: Date(), usage: .noCredentialsError)
}

#Preview("Gauge Small", as: .systemSmall) {
    CodexUsageGaugeWidget()
} timeline: {
    CodexUsageEntry(date: Date(), usage: .placeholder)
}

#Preview("Gauge Medium", as: .systemMedium) {
    CodexUsageGaugeWidget()
} timeline: {
    CodexUsageEntry(date: Date(), usage: .placeholder)
}
