import SwiftUI
import UIKit

enum VeyraColor {
    static let background = adaptive(light: 0xF7F7FA, dark: 0x0D0F14)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x171A21)
    static let surfaceElevated = adaptive(light: 0xEFEFF5, dark: 0x20242D)
    static let textPrimary = adaptive(light: 0x171820, dark: 0xF5F5F7)
    static let textSecondary = adaptive(light: 0x666A78, dark: 0xA7ABBA)
    static let accent = adaptive(light: 0x6657D9, dark: 0x9B8CFF)
    static let accentMuted = adaptive(light: 0xE8E4FF, dark: 0x292442)
    static let divider = adaptive(light: 0xDDDDE5, dark: 0x2B303B)
    static let success = adaptive(light: 0x238A61, dark: 0x58D39B)
    static let danger = adaptive(light: 0xC53D55, dark: 0xFF7188)

    private static func adaptive(light: Int, dark: Int) -> Color {
        Color(
            uiColor: UIColor { traits in
                UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
            }
        )
    }
}

private extension UIColor {
    convenience init(hex: Int) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
