import Foundation
import InkMetal
import Testing

@testable import FeelLab

@MainActor
struct TuningSettingsStoreTests {
    let suite = UserDefaults(suiteName: UUID().uuidString)!

    func store(defaultsID: String = "a", baked: InkParameters = .defaults) -> TuningSettingsStore {
        TuningSettingsStore(defaults: suite, bakedDefaultsID: defaultsID, bakedParameters: baked)
    }

    var tuned: InkParameters {
        var parameters = InkParameters.defaults
        parameters.sharpness = 2
        parameters.smoothing = 0.1
        return parameters
    }

    @Test func firstLaunchReturnsBakedDefaults() {
        #expect(store().load() == .defaults)
        #expect(store().previous() == nil)
    }

    @Test func savedSettingsSurviveRelaunch() {
        store().save(tuned)
        #expect(store().load() == tuned)
    }

    @Test func newBakedDefaultsAreAdoptedAndOldKeptAsPrevious() {
        store(defaultsID: "a").save(tuned)
        var baked = InkParameters.defaults
        baked.thickWidth = 7
        let newBuild = store(defaultsID: "b", baked: baked)
        #expect(newBuild.load() == baked)
        #expect(newBuild.previous() == tuned)
        #expect(store(defaultsID: "b", baked: baked).load() == baked)
    }

    @Test func unknownSchemaFallsBackToDefaults() {
        let json = #"{"schemaVersion": 99, "defaultsID": "a", "parameters": {"future": true}}"#
        suite.set(Data(json.utf8), forKey: TuningSettingsStore.currentKey)
        #expect(store().load() == .defaults)
    }

    @Test func copyJSONRoundTrips() throws {
        let json = store().copyJSON(tuned)
        let settings = try JSONDecoder().decode(TuningSettings.self, from: Data(json.utf8))
        #expect(settings.schemaVersion == TuningSettingsStore.schemaVersion)
        #expect(settings.defaultsID == "a")
        #expect(settings.parameters == tuned)
    }
}
