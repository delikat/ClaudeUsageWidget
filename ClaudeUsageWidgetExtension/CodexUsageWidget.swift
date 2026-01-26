import WidgetKit
import SwiftUI
import Shared

struct CodexProvider: TimelineProvider {
    func placeholder(in context: Context) -> CodexUsageEntry {
        CodexUsageEntry(date: Date(), usage: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (CodexUsageEntry) -> Void) {
        let usage = CodexUsageCacheManager.shared.read() ?? .placeholder
        completion(CodexUsageEntry(date: Date(), usage: usage))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CodexUsageEntry>) -> Void) {
        let usage = CodexUsageCacheManager.shared.read() ?? .noCredentialsError
        let entry = CodexUsageEntry(date: Date(), usage: usage)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct CodexUsageEntry: TimelineEntry {
    let date: Date
    let usage: CodexCachedUsage
}

struct CodexSmallWidgetView: View {
    let entry: CodexUsageEntry

    var body: some View {
        if entry.usage.error != nil {
            CodexErrorView(error: entry.usage.error)
        } else {
            CodexUsageCard(
                title: "5 Hour",
                subtitle: entry.usage.planTitle ?? "Codex Usage",
                window: entry.usage.primaryWindow,
                fetchedAt: entry.usage.fetchedAt,
                showRefresh: true
            )
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
                    subtitle: entry.usage.planTitle ?? "Codex Usage",
                    window: entry.usage.primaryWindow,
                    fetchedAt: entry.usage.fetchedAt,
                    showRefresh: true
                )

                CodexUsageCard(
                    title: "7 Day",
                    subtitle: entry.usage.planTitle ?? "Codex Usage",
                    window: entry.usage.secondaryWindow,
                    fetchedAt: entry.usage.fetchedAt,
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
    let window: CodexUsageWindow
    let fetchedAt: Date
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
                if let percent = window.usedPercent {
                    HStack(spacing: 3) {
                        Image(systemName: statusIcon(for: percent))
                            .font(.system(size: 12, weight: .bold))
                        Text("\(Int(percent))%")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(usageColor(for: percent))
                } else if let tokens = window.tokens {
                    Text(formatCompactNumber(tokens))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                } else {
                    Text("--")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            if let percent = window.usedPercent {
                ProgressBar(value: percent, color: usageColor(for: percent))
            } else {
                TokenSummaryView(tokens: window.tokens, requests: window.requests)
            }

            HStack {
                if showRefresh {
                    RefreshButton()
                }
                Spacer()
                if let resetAt = window.resetsAt {
                    Text("Resets in \(resetAt, style: .relative)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Updated \(fetchedAt, style: .relative)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .cardStyle()
    }
}

struct TokenSummaryView: View {
    let tokens: Int?
    let requests: Int?

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Tokens")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(tokens.map { formatCompactNumber($0) } ?? "--")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            }
            Spacer()
            VStack(alignment: .leading, spacing: 2) {
                Text("Requests")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(requests.map { formatCompactNumber($0) } ?? "--")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            }
        }
    }
}

struct CodexErrorView: View {
    let error: CodexCachedUsage.CacheError?

    private var icon: String {
        switch error {
        case .networkError:
            return "wifi.slash"
        case .invalidCredentials:
            return "key.slash"
        case .unsupported:
            return "exclamationmark.triangle.fill"
        case .invalidResponse:
            return "doc.questionmark"
        default:
            return "exclamationmark.triangle.fill"
        }
    }

    private var title: String {
        switch error {
        case .networkError:
            return "Network Error"
        case .invalidCredentials:
            return "Invalid Credentials"
        case .apiError:
            return "API Error"
        case .invalidResponse:
            return "Unexpected Response"
        case .unsupported:
            return "Experimental Disabled"
        default:
            return "Setup Required"
        }
    }

    private var message: String {
        switch error {
        case .networkError:
            return "Check connection"
        case .invalidCredentials:
            return "Update Codex auth"
        case .apiError:
            return "Try again later"
        case .invalidResponse:
            return "Retry later"
        case .unsupported:
            return "Enable in settings"
        default:
            return "Add API key"
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
                        Text(entry.usage.planTitle ?? "Codex Usage")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    RefreshButton()
                }

                if let percent = entry.usage.primaryWindow.usedPercent {
                    CircularRingGauge(
                        value: percent,
                        color: usageColor(for: percent),
                        lineWidth: 8
                    )
                } else {
                    TokenSummaryView(tokens: entry.usage.primaryWindow.tokens, requests: entry.usage.primaryWindow.requests)
                }

                if let resetAt = entry.usage.primaryWindow.resetsAt {
                    Text("in \(resetAt, style: .relative)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Updated \(entry.usage.fetchedAt, style: .relative)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .cardStyle()
            .padding(6)
        }
    }
}

struct CodexGaugeCard: View {
    let title: String
    let subtitle: String
    let window: CodexUsageWindow
    let fetchedAt: Date
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

            if let percent = window.usedPercent {
                CircularRingGauge(
                    value: percent,
                    color: usageColor(for: percent),
                    lineWidth: 8
                )
            } else {
                TokenSummaryView(tokens: window.tokens, requests: window.requests)
            }

            if let resetAt = window.resetsAt {
                Text("in \(resetAt, style: .relative)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("Updated \(fetchedAt, style: .relative)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .cardStyle()
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
                    subtitle: entry.usage.planTitle ?? "Codex Usage",
                    window: entry.usage.primaryWindow,
                    fetchedAt: entry.usage.fetchedAt,
                    showRefresh: true
                )

                CodexGaugeCard(
                    title: "7 Day",
                    subtitle: entry.usage.planTitle ?? "Codex Usage",
                    window: entry.usage.secondaryWindow,
                    fetchedAt: entry.usage.fetchedAt,
                    showRefresh: false
                )
            }
            .padding(6)
        }
    }
}

struct CodexUsageGaugeWidgetEntryView: View {
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

struct CodexUsageWidget: Widget {
    let kind: String = "CodexUsageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CodexProvider()) { entry in
            CodexUsageWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Codex Usage")
        .description("Monitor your OpenAI Codex usage")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct CodexUsageGaugeWidget: Widget {
    let kind: String = "CodexUsageGaugeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CodexProvider()) { entry in
            CodexUsageGaugeWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Codex Usage (Gauge)")
        .description("Circular gauge showing Codex usage")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

func formatCompactNumber(_ value: Int) -> String {
    let num = Double(value)
    switch num {
    case 0..<1_000:
        return "\(value)"
    case 1_000..<1_000_000:
        return String(format: "%.1fk", num / 1_000)
    case 1_000_000..<1_000_000_000:
        return String(format: "%.1fM", num / 1_000_000)
    default:
        return String(format: "%.1fB", num / 1_000_000_000)
    }
}

#Preview("Codex Small", as: .systemSmall) {
    CodexUsageWidget()
} timeline: {
    CodexUsageEntry(date: Date(), usage: .placeholder)
}

#Preview("Codex Medium", as: .systemMedium) {
    CodexUsageWidget()
} timeline: {
    CodexUsageEntry(date: Date(), usage: .placeholder)
}

#Preview("Codex Error", as: .systemSmall) {
    CodexUsageWidget()
} timeline: {
    CodexUsageEntry(date: Date(), usage: .noCredentialsError)
}

#Preview("Codex Gauge Small", as: .systemSmall) {
    CodexUsageGaugeWidget()
} timeline: {
    CodexUsageEntry(date: Date(), usage: .placeholder)
}

#Preview("Codex Gauge Medium", as: .systemMedium) {
    CodexUsageGaugeWidget()
} timeline: {
    CodexUsageEntry(date: Date(), usage: .placeholder)
}
