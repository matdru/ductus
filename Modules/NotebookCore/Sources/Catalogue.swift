import Foundation

/// A string-backed catalogue value. Values written by a newer app that this one doesn't know decode as
/// `fallback`, so an old app can still open the notebook.
public protocol CatalogueValue: RawRepresentable, Codable, Sendable, Hashable, CaseIterable
where RawValue == String {
    static var fallback: Self { get }
}

extension CatalogueValue {
    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? .fallback
    }
}

/// Paper types; see the Product & Design Brief for what each looks like.
public enum PaperType: String, CatalogueValue {
    case classicLined, fineLined, dotGrid, squared, engineering, legal, blank, cornell, music
    public static let fallback = PaperType.fineLined
}

public enum PaperColor: String, CatalogueValue {
    case white, ivory, cream, canary, recycled, charcoal
    public static let fallback = PaperColor.ivory
}

public struct Paper: Sendable, Codable, Hashable {
    public var type: PaperType
    public var color: PaperColor

    public init(type: PaperType, color: PaperColor) {
        self.type = type
        self.color = color
    }

    public static let `default` = Paper(type: .fineLined, color: .ivory)

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(PaperType.self, forKey: .type) ?? Self.default.type
        color = try container.decodeIfPresent(PaperColor.self, forKey: .color) ?? Self.default.color
    }
}

public enum CoverMaterial: String, CatalogueValue {
    case cloth, leather, kraft, linen, plain
    public static let fallback = CoverMaterial.cloth
}

public struct Cover: Sendable, Codable, Hashable {
    public var material: CoverMaterial
    /// A name from the cover colour palette; the palette itself is still being designed (DRU-24).
    public var colorName: String

    public init(material: CoverMaterial, colorName: String) {
        self.material = material
        self.colorName = colorName
    }

    public static let `default` = Cover(material: .cloth, colorName: "navy")

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        material = try container.decodeIfPresent(CoverMaterial.self, forKey: .material) ?? Self.default.material
        colorName = try container.decodeIfPresent(String.self, forKey: .colorName) ?? Self.default.colorName
    }
}

/// Physical page sizes, portrait, in points (1/72 inch).
public enum PageSize: String, CatalogueValue {
    case a5, a4, letter, pocket
    public static let fallback = PageSize.a5

    public var width: Double {
        switch self {
        case .a5: Self.points(millimetres: 148)
        case .a4: Self.points(millimetres: 210)
        case .letter: 612
        case .pocket: Self.points(millimetres: 105)
        }
    }

    public var height: Double {
        switch self {
        case .a5: Self.points(millimetres: 210)
        case .a4: Self.points(millimetres: 297)
        case .letter: 792
        case .pocket: Self.points(millimetres: 148)
        }
    }

    static func points(millimetres: Double) -> Double { millimetres / 25.4 * 72 }
}
