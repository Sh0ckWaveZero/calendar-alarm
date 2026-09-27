import SwiftUI
import UIKit

/// Design tokens ported from the original app's theme.ts (light/dark pairs).
enum Theme {
    private static func dynamicColor(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }

    static let background = dynamicColor(light: 0xF7F7FA, dark: 0x000000)
    static let card = dynamicColor(light: 0xFFFFFF, dark: 0x1C1C1E)
    static let text = dynamicColor(light: 0x1C1C1E, dark: 0xF2F2F7)
    static let subtext = dynamicColor(light: 0x6E6E73, dark: 0x9B9BA1)
    static let border = dynamicColor(light: 0xE5E5EA, dark: 0x2C2C2E)
    static let accent = dynamicColor(light: 0x5E5CE6, dark: 0x7D7AFF)
    static let danger = dynamicColor(light: 0xFF3B30, dark: 0xFF453A)
    static let bellOn = dynamicColor(light: 0xFF9F0A, dark: 0xFFB340)
    static let bellOff = dynamicColor(light: 0xC7C7CC, dark: 0x48484A)

    /// Palette offered in the event form (original per-account fallback colors plus two extras).
    static let eventPalette: [UInt32] = [
        0x5E5CE6, 0xFF9F0A, 0x30D158, 0xFF375F, 0x64D2FF, 0xBF5AF2,
    ]

    static func color(for hex: UInt32) -> Color {
        Color(uiColor: UIColor(hex: hex))
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((hex & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(hex & 0x0000FF) / 255.0,
            alpha: 1
        )
    }

    convenience init(hexString: String) {
        let sanitized = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)
        self.init(hex: UInt32(value & 0xFFFFFF))
    }
}

extension Color {
    init(hexString: String) {
        self.init(uiColor: UIColor(hexString: hexString))
    }
}
