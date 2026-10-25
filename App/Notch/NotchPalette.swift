import AppKit
import SleeperKit
import SwiftUI

/// Colores semánticos de docs/DESIGN.md §Colores.
///
/// El notch es negro en modo claro y oscuro (DynamicNotchKit dibuja el fondo negro), así que
/// las vistas fuerzan `colorScheme = .dark` y usan las variantes oscuras, las únicas con
/// contraste >= 4.5:1 sobre negro. La variante clara queda para un fallback flotante (FN-011).
enum NotchPalette {
    static func color(for tone: ScoreTone, scheme: ColorScheme = .dark) -> Color {
        let dark = scheme == .dark
        switch tone {
        case .winning: return hex(dark ? 0x34C759 : 0x248A3D)
        case .losing: return hex(dark ? 0xFF453A : 0xD70015)
        case .stale: return hex(dark ? 0x8E8E93 : 0x6C6C70)
        // La spec pide blanco neutro para el empate (DESIGN.md propone amarillo; manda la spec).
        case .tied, .noMatchup: return dark ? .white : .black
        }
    }

    static let secondary = Color.white.opacity(0.7)

    private static func hex(_ value: UInt32) -> Color {
        Color(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
