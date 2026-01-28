import SwiftUI

// MARK: - Shared Design System Colors

public extension Color {
    // Usage status colors (shared across all widgets)
    static let dsGreen = Color.green
    static let dsOrange = Color.orange
    static let dsRed = Color.red

    // Card styling colors
    static let dsCardBackground = Color(nsColor: .controlBackgroundColor).opacity(0.4)
    static let dsCardBorder = Color.gray.opacity(0.2)
    static let dsTrackBackground = Color.secondary.opacity(0.15)
}

// MARK: - Usage Color Helper

public func dsUsageColor(for value: Double) -> Color {
    switch value {
    case 0..<50:
        return .dsGreen
    case 50..<80:
        return .dsOrange
    default:
        return .dsRed
    }
}

// MARK: - Card Background Modifier

public struct DSCardBackground: ViewModifier {
    public var padding: CGFloat

    public init(padding: CGFloat = 12) {
        self.padding = padding
    }

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dsCardBackground)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.dsCardBorder, lineWidth: 1)
            )
    }
}

public extension View {
    func dsCardStyle(padding: CGFloat = 12) -> some View {
        modifier(DSCardBackground(padding: padding))
    }
}

// MARK: - Progress Bar

public struct DSProgressBar: View {
    public let value: Double
    public let color: Color
    private let barHeight: CGFloat = 8
    private let cornerRadius: CGFloat = 4

    public init(value: Double, color: Color) {
        self.value = value
        self.color = color
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.dsTrackBackground)
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

public struct DSCircularRingGauge: View {
    public let value: Double
    public let color: Color
    public let lineWidth: CGFloat
    public let percentageFontSize: CGFloat

    public init(value: Double, color: Color, lineWidth: CGFloat = 8, percentageFontSize: CGFloat = 14) {
        self.value = value
        self.color = color
        self.lineWidth = lineWidth
        self.percentageFontSize = percentageFontSize
    }

    public var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(Color.dsTrackBackground, lineWidth: lineWidth)

            // Filled arc
            Circle()
                .trim(from: 0, to: CGFloat(min(value, 100)) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.8), value: value)

            // Percentage text (color-coded, not white)
            Text("\(Int(value))%")
                .font(.system(size: percentageFontSize, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
    }
}
