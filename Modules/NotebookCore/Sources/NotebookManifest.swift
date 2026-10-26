import Foundation

/// The on-disk form of a notebook's `manifest.json`: the notebook wrapped with a schema version.
public enum NotebookManifest {
    public static let schemaVersion = 1

    public enum Error: Swift.Error, Equatable {
        /// Written by a newer app. Refused rather than decoded, so saving it back can't drop fields we don't know.
        case unsupportedVersion(Int)
    }

    private struct Envelope: Codable {
        var schemaVersion: Int
        var notebook: Notebook
    }

    private struct VersionProbe: Decodable {
        var schemaVersion: Int
    }

    public static func encode(_ notebook: Notebook) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        // Seconds since 2001 (Date's own representation) round-trip exactly, so a reloaded notebook compares
        // equal to the one saved. ISO 8601 drops sub-second precision; seconds since 1970 rounds it.
        encoder.dateEncodingStrategy = .deferredToDate
        return try encoder.encode(Envelope(schemaVersion: schemaVersion, notebook: notebook))
    }

    public static func decode(_ data: Data) throws -> Notebook {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        let version = try decoder.decode(VersionProbe.self, from: data).schemaVersion
        guard version <= schemaVersion else { throw Error.unsupportedVersion(version) }
        return try decoder.decode(Envelope.self, from: data).notebook
    }
}
