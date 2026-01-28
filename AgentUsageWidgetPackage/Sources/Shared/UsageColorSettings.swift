import Foundation
import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

public enum UsageColorKeys {
    public static let ring = "usage_color_ring"
    public static let ringUseStatus = "usage_color_ring_use_status"
    public static let statusGreen = "usage_color_green"
    public static let statusOrange = "usage_color_orange"
    public static let statusRed = "usage_color_red"
}

public enum UsageColorSettings {
    public static func loadRingColor(defaultColor: Color) -> Color {
        loadColor(forKey: UsageColorKeys.ring, defaultColor: defaultColor)
    }

    public static func loadRingUseStatus(defaultValue: Bool = true) -> Bool {
        let defaults = AppGroupDefaults.shared
        guard let defaults else { return defaultValue }
        if defaults.object(forKey: UsageColorKeys.ringUseStatus) == nil {
            return defaultValue
        }
        return defaults.bool(forKey: UsageColorKeys.ringUseStatus)
    }

    public static func loadStatusGreenColor(defaultColor: Color) -> Color {
        loadColor(forKey: UsageColorKeys.statusGreen, defaultColor: defaultColor)
    }

    public static func loadStatusOrangeColor(defaultColor: Color) -> Color {
        loadColor(forKey: UsageColorKeys.statusOrange, defaultColor: defaultColor)
    }

    public static func loadStatusRedColor(defaultColor: Color) -> Color {
        loadColor(forKey: UsageColorKeys.statusRed, defaultColor: defaultColor)
    }

    public static func saveRingColor(_ color: Color) {
        saveColor(color, forKey: UsageColorKeys.ring)
    }

    public static func saveRingUseStatus(_ value: Bool) {
        let defaults = AppGroupDefaults.shared
        defaults?.set(value, forKey: UsageColorKeys.ringUseStatus)
    }

    public static func saveStatusGreenColor(_ color: Color) {
        saveColor(color, forKey: UsageColorKeys.statusGreen)
    }

    public static func saveStatusOrangeColor(_ color: Color) {
        saveColor(color, forKey: UsageColorKeys.statusOrange)
    }

    public static func saveStatusRedColor(_ color: Color) {
        saveColor(color, forKey: UsageColorKeys.statusRed)
    }

    public static func resetToDefaults() {
        let defaults = AppGroupDefaults.shared
        defaults?.removeObject(forKey: UsageColorKeys.ring)
        defaults?.removeObject(forKey: UsageColorKeys.ringUseStatus)
        defaults?.removeObject(forKey: UsageColorKeys.statusGreen)
        defaults?.removeObject(forKey: UsageColorKeys.statusOrange)
        defaults?.removeObject(forKey: UsageColorKeys.statusRed)
    }

    private static func loadColor(forKey key: String, defaultColor: Color) -> Color {
        let defaults = AppGroupDefaults.shared
        let storedValue = defaults?.string(forKey: key)
        return ColorHexCodec.resolveColor(from: storedValue, defaultColor: defaultColor)
    }

    private static func saveColor(_ color: Color, forKey key: String) {
        guard let hexValue = ColorHexCodec.hexString(from: color) else { return }
        let defaults = AppGroupDefaults.shared
        defaults?.set(hexValue, forKey: key)
    }
}

public enum ColorHexCodec {
    public static func resolveColor(from storedValue: String?, defaultColor: Color) -> Color {
        guard let storedValue, let color = color(from: storedValue) else {
            return defaultColor
        }
        return color
    }

    public static func color(from hex: String) -> Color? {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        let length = normalized.count
        guard length == 6 || length == 8 else { return nil }

        var value: UInt64 = 0
        guard Scanner(string: normalized).scanHexInt64(&value) else { return nil }

        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double

        if length == 6 {
            red = Double((value >> 16) & 0xFF) / 255.0
            green = Double((value >> 8) & 0xFF) / 255.0
            blue = Double(value & 0xFF) / 255.0
            alpha = 1.0
        } else {
            red = Double((value >> 24) & 0xFF) / 255.0
            green = Double((value >> 16) & 0xFF) / 255.0
            blue = Double((value >> 8) & 0xFF) / 255.0
            alpha = Double(value & 0xFF) / 255.0
        }

        return Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    public static func hexString(from color: Color) -> String? {
        #if canImport(AppKit)
        guard let nsColor = NSColor(color).usingColorSpace(.sRGB) else { return nil }
        let red = Int(round(nsColor.redComponent * 255))
        let green = Int(round(nsColor.greenComponent * 255))
        let blue = Int(round(nsColor.blueComponent * 255))
        let alpha = Int(round(nsColor.alphaComponent * 255))
        return String(format: "#%02X%02X%02X%02X", red, green, blue, alpha)
        #elseif canImport(UIKit)
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        return String(
            format: "#%02X%02X%02X%02X",
            Int(round(red * 255)),
            Int(round(green * 255)),
            Int(round(blue * 255)),
            Int(round(alpha * 255))
        )
        #else
        return nil
        #endif
    }
}
