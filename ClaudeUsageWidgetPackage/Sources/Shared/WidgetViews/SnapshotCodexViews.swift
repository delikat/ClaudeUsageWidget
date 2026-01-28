import SwiftUI

public struct SnapshotCodexSmallWidgetView: View {
    public let usage: SnapshotUsageData

    public init(usage: SnapshotUsageData) {
        self.usage = usage
    }

    public var body: some View {
        if usage.error != nil {
            SnapshotCodexErrorView(error: usage.error)
        } else {
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("5 Hour")
                            .font(.system(size: 13, weight: .semibold))
                        Text(usage.planTitle ?? "Usage Limit")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer()
                    Text("\(Int(usage.fiveHourUsage))%")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(dsUsageColor(for: usage.fiveHourUsage))
                }

                DSProgressBar(value: usage.fiveHourUsage, color: dsUsageColor(for: usage.fiveHourUsage))

                HStack {
                    SnapshotRefreshButton()
                    Spacer()
                    if let resetText = usage.fiveHourResetText {
                        (Text("Resets in ") + Text(resetText))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .dsCardStyle(padding: 16)
            .padding(6)
        }
    }
}

public struct SnapshotCodexMediumWidgetView: View {
    public let usage: SnapshotUsageData

    public init(usage: SnapshotUsageData) {
        self.usage = usage
    }

    public var body: some View {
        if usage.error != nil {
            SnapshotCodexErrorView(error: usage.error)
        } else {
            HStack(spacing: 8) {
                SnapshotCodexUsageCard(
                    title: "5 Hour",
                    subtitle: usage.planTitle ?? "Usage Limit",
                    value: usage.fiveHourUsage,
                    resetText: usage.fiveHourResetText,
                    showRefresh: true
                )

                SnapshotCodexUsageCard(
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

public struct SnapshotCodexUsageCard: View {
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

public struct SnapshotCodexErrorView: View {
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
            return "Run `chatgpt auth`"
        case .apiError:
            return "Try again later"
        case .invalidCredentialsFormat:
            return "Re-authenticate ChatGPT"
        default:
            return "Install ChatGPT CLI"
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
