import Foundation
import SwiftUI

public struct SnapshotUsageData: Sendable {
    public let planTitle: String?
    public let fiveHourUsage: Double
    public let sevenDayUsage: Double
    public let fiveHourResetText: String?
    public let sevenDayResetText: String?
    public let error: CachedUsage.CacheError?

    public init(
        planTitle: String?,
        fiveHourUsage: Double,
        sevenDayUsage: Double,
        fiveHourResetText: String?,
        sevenDayResetText: String?,
        error: CachedUsage.CacheError?
    ) {
        self.planTitle = planTitle
        self.fiveHourUsage = fiveHourUsage
        self.sevenDayUsage = sevenDayUsage
        self.fiveHourResetText = fiveHourResetText
        self.sevenDayResetText = sevenDayResetText
        self.error = error
    }
}

public struct SnapshotMonthlyData: Sendable {
    public let stats: MonthlyStats?
    public let error: CachedMonthlyUsage.CacheError?

    public init(stats: MonthlyStats?, error: CachedMonthlyUsage.CacheError?) {
        self.stats = stats
        self.error = error
    }
}

public struct SnapshotSmallWidgetView: View {
    public let usage: SnapshotUsageData

    public init(usage: SnapshotUsageData) {
        self.usage = usage
    }

    public var body: some View {
        if usage.error != nil {
            SnapshotErrorView(error: usage.error)
        } else {
            VStack(spacing: 6) {
                HStack {
                    Text("5 Hour")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    SnapshotRefreshButton()
                }

                Text(usage.planTitle ?? "Usage Limit")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                DSCircularRingGauge(
                    value: usage.fiveHourUsage,
                    color: dsUsageColor(for: usage.fiveHourUsage),
                    lineWidth: 8,
                    percentageFontSize: 14
                )

                if let resetText = usage.fiveHourResetText {
                    (Text("in ") + Text(resetText))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .dsCardStyle()
            .padding(6)
        }
    }
}

public struct SnapshotMediumWidgetView: View {
    public let usage: SnapshotUsageData

    public init(usage: SnapshotUsageData) {
        self.usage = usage
    }

    public var body: some View {
        if usage.error != nil {
            SnapshotErrorView(error: usage.error)
        } else {
            HStack(spacing: 8) {
                SnapshotUsageCard(
                    title: "5 Hour",
                    subtitle: usage.planTitle ?? "Usage Limit",
                    value: usage.fiveHourUsage,
                    resetText: usage.fiveHourResetText,
                    showRefresh: true
                )

                SnapshotUsageCard(
                    title: "7 Day",
                    subtitle: usage.planTitle ?? "Usage Limit",
                    value: usage.sevenDayUsage,
                    resetText: usage.sevenDayResetText,
                    showRefresh: false
                )
            }
            .padding(6)
        }
    }
}

public struct SnapshotLargeWidgetView: View {
    public let usage: SnapshotUsageData
    public let monthly: SnapshotMonthlyData

    public init(usage: SnapshotUsageData, monthly: SnapshotMonthlyData) {
        self.usage = usage
        self.monthly = monthly
    }

    public var body: some View {
        if monthly.error != nil || monthly.stats == nil {
            SnapshotMonthlyErrorView(error: monthly.error)
        } else if let stats = monthly.stats {
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
                    SnapshotMonthlyRefreshButton()
                }

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(formattedCost(stats.totalCost))
                            .font(.system(size: 30, weight: .bold, design: .monospaced))

                        SnapshotTokenBreakdownView(stats: stats)

                        SnapshotModelSummaryView(models: stats.models)
                    }

                    Spacer()

                    SnapshotMiniGaugeStack(usage: usage)
                }
            }
            .dsCardStyle(padding: 16)
            .padding(6)
        }
    }
}

public struct SnapshotSmallGaugeWidgetView: View {
    public let usage: SnapshotUsageData

    public init(usage: SnapshotUsageData) {
        self.usage = usage
    }

    public var body: some View {
        SnapshotSmallWidgetView(usage: usage)
    }
}

public struct SnapshotMediumGaugeWidgetView: View {
    public let usage: SnapshotUsageData

    public init(usage: SnapshotUsageData) {
        self.usage = usage
    }

    public var body: some View {
        if usage.error != nil {
            SnapshotErrorView(error: usage.error)
        } else {
            HStack(spacing: 8) {
                SnapshotGaugeCard(
                    title: "5 Hour",
                    subtitle: usage.planTitle ?? "Usage Limit",
                    value: usage.fiveHourUsage,
                    resetText: usage.fiveHourResetText,
                    showRefresh: true
                )

                SnapshotGaugeCard(
                    title: "7 Day",
                    subtitle: usage.planTitle ?? "Usage Limit",
                    value: usage.sevenDayUsage,
                    resetText: usage.sevenDayResetText,
                    showRefresh: false
                )
            }
            .padding(6)
        }
    }
}

public struct SnapshotUsageCard: View {
    public let title: String
    public let subtitle: String
    public let value: Double
    public let resetText: String?
    public let showRefresh: Bool

    public init(
        title: String,
        subtitle: String,
        value: Double,
        resetText: String?,
        showRefresh: Bool
    ) {
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.resetText = resetText
        self.showRefresh = showRefresh
    }

    public var body: some View {
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
            }

            DSProgressBar(value: value, color: dsUsageColor(for: value))

            HStack {
                if showRefresh {
                    SnapshotRefreshButton()
                }
                Spacer()
                if let resetText {
                    (Text("Resets in ") + Text(resetText))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .dsCardStyle()
    }
}

public struct SnapshotGaugeCard: View {
    public let title: String
    public let subtitle: String
    public let value: Double
    public let resetText: String?
    public let showRefresh: Bool

    public init(
        title: String,
        subtitle: String,
        value: Double,
        resetText: String?,
        showRefresh: Bool
    ) {
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.resetText = resetText
        self.showRefresh = showRefresh
    }

    public var body: some View {
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
                    SnapshotRefreshButton()
                }
            }

            DSCircularRingGauge(
                value: value,
                color: dsUsageColor(for: value),
                lineWidth: 8,
                percentageFontSize: 14
            )

            if let resetText {
                (Text("in ") + Text(resetText))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .dsCardStyle()
    }
}

public struct SnapshotErrorView: View {
    public let error: CachedUsage.CacheError?

    public init(error: CachedUsage.CacheError?) {
        self.error = error
    }

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

    public var body: some View {
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

public struct SnapshotMonthlyErrorView: View {
    public let error: CachedMonthlyUsage.CacheError?

    public init(error: CachedMonthlyUsage.CacheError?) {
        self.error = error
    }

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

    public var body: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                SnapshotMonthlyRefreshButton()
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

struct SnapshotRefreshButton: View {
    var body: some View {
        Button(action: {}) {
            Image(systemName: "arrow.clockwise")
                .font(.caption)
        }
        .buttonStyle(.plain)
    }
}

struct SnapshotMonthlyRefreshButton: View {
    var body: some View {
        Button(action: {}) {
            Image(systemName: "arrow.clockwise")
                .font(.caption)
        }
        .buttonStyle(.plain)
    }
}

private struct SnapshotTokenBreakdownView: View {
    let stats: MonthlyStats

    var body: some View {
        HStack(spacing: 12) {
            SnapshotTokenStat(label: "Input", value: stats.inputTokens)
            SnapshotTokenStat(label: "Output", value: stats.outputTokens)
            SnapshotTokenStat(label: "Cache Read", value: stats.cacheReadInputTokens)
            SnapshotTokenStat(label: "Cache Create", value: stats.cacheCreationInputTokens)
        }
    }
}

private struct SnapshotTokenStat: View {
    let label: String
    let value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
            Text(formattedTokens(value))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
        }
    }
}

private struct SnapshotModelSummaryView: View {
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
                }
            }
        }
    }
}

private struct SnapshotMiniGaugeStack: View {
    let usage: SnapshotUsageData

    var body: some View {
        VStack(spacing: 8) {
            SnapshotMiniGauge(label: "5h", value: usage.fiveHourUsage)
            SnapshotMiniGauge(label: "7d", value: usage.sevenDayUsage)
        }
    }
}

private struct SnapshotMiniGauge: View {
    let label: String
    let value: Double

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            DSCircularRingGauge(
                value: value,
                color: dsUsageColor(for: value),
                lineWidth: 6,
                percentageFontSize: 10
            )
            .frame(width: 44, height: 44)
        }
    }
}

private func formattedCost(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "USD"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.maximumFractionDigits = 2
    formatter.minimumFractionDigits = 2
    return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
}

private func formattedTokens(_ value: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
}

private func monthTitle(for identifier: String) -> String {
    let parts = identifier.split(separator: "-")
    guard parts.count == 2,
          let year = Int(parts[0]),
          let month = Int(parts[1]) else {
        return identifier
    }
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = 1
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    guard let date = calendar.date(from: components) else {
        return identifier
    }
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "LLLL yyyy"
    return formatter.string(from: date)
}

private func shortModelName(_ model: String) -> String {
    let trimmed = model.replacingOccurrences(of: "claude-", with: "")
    return trimmed.isEmpty ? model : trimmed
}
