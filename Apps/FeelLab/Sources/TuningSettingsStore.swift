import Foundation
import InkMetal

/// What "Copy settings" puts on the clipboard and what's persisted between launches.
struct TuningSettings: Codable, Equatable {
    var schemaVersion: Int
    /// Which baked-in defaults these settings were tuned from.
    var defaultsID: String
    var parameters: InkParameters
}

/// Persists the tuning panel's settings. When a build ships new baked defaults (a different `defaultsID`),
/// those win, because the author pasted settings precisely to make them the defaults; what was saved before
/// stays available as `previous()`.
@MainActor
struct TuningSettingsStore {
    static let schemaVersion = 1
    static let currentKey = "tuning.current"
    static let previousKey = "tuning.previous"

    private let defaults: UserDefaults
    private let bakedDefaultsID: String
    private let bakedParameters: InkParameters

    init(
        defaults: UserDefaults = .standard, bakedDefaultsID: String = InkParameters.defaultsID,
        bakedParameters: InkParameters = .defaults
    ) {
        self.defaults = defaults
        self.bakedDefaultsID = bakedDefaultsID
        self.bakedParameters = bakedParameters
    }

    func load() -> InkParameters {
        guard let stored = settings(forKey: Self.currentKey) else { return bakedParameters }
        guard stored.defaultsID == bakedDefaultsID else {
            write(stored, forKey: Self.previousKey)
            save(bakedParameters)
            return bakedParameters
        }
        return stored.parameters
    }

    func save(_ parameters: InkParameters) {
        write(envelope(parameters), forKey: Self.currentKey)
    }

    /// Settings displaced by a defaults change, if any.
    func previous() -> InkParameters? {
        settings(forKey: Self.previousKey)?.parameters
    }

    func copyJSON(_ parameters: InkParameters) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(envelope(parameters)) else { return "" }
        return String(bytes: data, encoding: .utf8) ?? ""
    }

    private func envelope(_ parameters: InkParameters) -> TuningSettings {
        TuningSettings(schemaVersion: Self.schemaVersion, defaultsID: bakedDefaultsID, parameters: parameters)
    }

    /// Unknown schema versions or undecodable data read as "nothing stored".
    private func settings(forKey key: String) -> TuningSettings? {
        guard let data = defaults.data(forKey: key),
            let settings = try? JSONDecoder().decode(TuningSettings.self, from: data),
            settings.schemaVersion == Self.schemaVersion
        else { return nil }
        return settings
    }

    private func write(_ settings: TuningSettings, forKey key: String) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
