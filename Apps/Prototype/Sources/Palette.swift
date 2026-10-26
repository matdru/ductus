import NotebookCore
import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255)
    }
}

extension PaperColor {
    var color: Color {
        switch self {
        case .white: Color(hex: 0xFFFFFE)
        case .ivory: Color(hex: 0xFBF7EC)
        case .cream: Color(hex: 0xF5ECD6)
        case .canary: Color(hex: 0xFBF1A0)
        case .recycled: Color(hex: 0xECEAE4)
        case .charcoal: Color(hex: 0x2E2F33)
        }
    }

    var isDark: Bool { self == .charcoal }
}

extension PaperType {
    var displayName: String {
        switch self {
        case .classicLined: "Classic Lined"
        case .fineLined: "Fine Lined"
        case .dotGrid: "Dot Grid"
        case .squared: "Squared"
        case .engineering: "Engineering"
        case .legal: "Legal Pad"
        case .blank: "Blank"
        case .cornell: "Cornell"
        case .music: "Music"
        }
    }
}

/// Cover colours under consideration (the real palette is DRU-24).
enum CoverPalette {
    static let names = ["navy", "forest", "oxblood", "mustard", "charcoal", "sand", "teal", "plum", "kraft", "sky"]

    private static let hexes: [String: UInt32] = [
        "navy": 0x1F2E4D, "forest": 0x2D4A3A, "oxblood": 0x6B2430, "mustard": 0xC9962E, "charcoal": 0x34363B,
        "sand": 0xCDB892, "teal": 0x2A6563, "plum": 0x553049, "kraft": 0xB08A5B, "sky": 0x7FA6C4,
    ]

    static func color(_ name: String) -> Color {
        Color(hex: hexes[name] ?? 0x1F2E4D)
    }
}

extension CoverMaterial {
    var displayName: String { rawValue.capitalized }
}
