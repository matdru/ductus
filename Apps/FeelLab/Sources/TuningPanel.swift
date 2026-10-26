import InkMetal
import SwiftUI

/// Side panel of live custom-engine knobs. Changes apply to the next frame and are saved immediately.
struct TuningPanel: View {
    @Bindable var model: FeelLabModel
    @State private var copied = false

    var body: some View {
        Form {
            Section("Fountain nib") {
                slider("Thin width", \.thinWidth, 0.25...4, unit: "pt")
                slider("Thick width", \.thickWidth, 2...16, unit: "pt")
                slider("Nib angle", \.nibAngleDegrees, -90...90, unit: "°")
                slider("Sharpness", \.sharpness, 0.5...8)
                slider("Roundness", \.nibRoundness, 0.1...1)
                Toggle("Nib follows Pencil lean", isOn: $model.parameters.followsPencilLean)
            }
            Section("Response") {
                slider("Pressure amount", \.pressureAmount, 0...1)
                slider("Pressure curve", \.pressureCurve, 0.3...3)
                slider("Speed thinning", \.speedThinning, 0...1)
            }
            Section {
                slider("Strength", \.smoothing, 0...1)
            } header: {
                Text("Smoothing")
            } footer: {
                Text("More smoothing = ink trails further behind the tip.")
            }
            Section {
                slider("Steadiness", \.steadiness, 0...15, unit: "pt")
                slider("Trail", \.trail, 0...6, unit: "pt")
            } header: {
                Text("Steady hand")
            } footer: {
                Text(
                    "Steadiness irons out wobbles smaller than its spacing; the last bit of a stroke settles as you "
                        + "write. Trail absorbs tremor near the nib. 0 turns either off.")
            }
            Section("Engine") {
                Toggle("Prediction", isOn: $model.parameters.predictionEnabled)
                Toggle("Baseline renderer (before)", isOn: $model.parameters.baselineRenderer)
            }
            Section {
                Button(copied ? "Copied" : "Copy settings", systemImage: "doc.on.doc") {
                    model.copyParametersJSON()
                    copied = true
                }
                Button("Reset to defaults", systemImage: "arrow.counterclockwise") { model.resetParameters() }
                if model.hasPreviousParameters {
                    Button("Restore previous", systemImage: "clock.arrow.circlepath") {
                        model.restorePreviousParameters()
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .onChange(of: model.parameters) { copied = false }
    }

    private func slider(
        _ title: String, _ keyPath: WritableKeyPath<InkParameters, Double>, _ range: ClosedRange<Double>,
        unit: String = ""
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%.2f", model.parameters[keyPath: keyPath]) + unit)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $model.parameters[dynamicMember: keyPath], in: range)
        }
    }
}
