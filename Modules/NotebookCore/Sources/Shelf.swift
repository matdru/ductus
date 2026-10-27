import Foundation

/// A named group of notebooks in the library sidebar. A notebook belongs to at most one shelf.
public struct Shelf: Sendable, Codable, Hashable, Identifiable {
    public let id: UUID
    public var name: String
    /// A name from the notebook colour palette.
    public var colorName: String

    public init(id: UUID = UUID(), name: String, colorName: String) {
        self.id = id
        self.name = name
        self.colorName = colorName
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Shelf"
        colorName = try container.decodeIfPresent(String.self, forKey: .colorName) ?? "graphite"
    }
}

/// The on-disk form of the library's own data (`library.json`): the shelves, with a schema version.
public enum LibraryManifest {
    public static let schemaVersion = 1

    public enum Error: Swift.Error, Equatable {
        /// Written by a newer app; refused so saving it back can't drop what we don't know.
        case unsupportedVersion(Int)
    }

    private struct Envelope: Codable {
        var schemaVersion: Int
        var shelves: [Shelf]
    }

    private struct VersionProbe: Decodable {
        var schemaVersion: Int
    }

    public static func encode(_ shelves: [Shelf]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(Envelope(schemaVersion: schemaVersion, shelves: shelves))
    }

    public static func decode(_ data: Data) throws -> [Shelf] {
        let decoder = JSONDecoder()
        let version = try decoder.decode(VersionProbe.self, from: data).schemaVersion
        guard version <= schemaVersion else { throw Error.unsupportedVersion(version) }
        return try decoder.decode(Envelope.self, from: data).shelves
    }
}
