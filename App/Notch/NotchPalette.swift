import AppKit
import SleeperKit
import SwiftUI

/// Colores semánticos de docs/DESIGN.md §Colores, con variante clara y oscura.
enum NotchPalette {
    static func color(for tone: ScoreTone) -> Color {
        switch tone {
        case .winning: dynamic(dark: 0x34C759, light: 0x248A3D)
        case .losing: dynamic(dark: 0xFF453A, light: 0xD70015)
        case .stale: dynamic(dark: 0x8E8E93, light: 0x6C6C70)
        // La spec pide blanco neutro para el empate (DESIGN.md propone amarillo; manda la spec).
        case .tied, .noMatchup: Color.primary
        }
    }

    static let secondary = Color.secondary

    private static func dynamic(dark: UInt32, light: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }
}

private extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
