import SwiftUI

struct ToolbarView: View {
    var config: PresetConfiguration
    var appState: AppState
    var onStart: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            switch config.presetType {
            case .circle:
                circleFields
            case .figure8:
                figure8Fields
            case .line:
                lineFields
            }

            speedField

            Divider()

            startingClickField

            Divider()

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Start") {
                    onStart()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!config.hasPlacedCenter)
            }
        }
        .padding(12)
        .frame(width: 260)
    }

    // MARK: - Preset-Specific Fields

    private var circleFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            if config.hasPlacedCenter {
                LabeledContent("Center") {
                    Text("\(Int(config.center.x)), \(Int(config.center.y))")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            pixelField("Radius", value: Binding(
                get: { config.radius },
                set: { config.radius = max(10, $0) }
            ), step: 5)
        }
    }

    private var figure8Fields: some View {
        VStack(alignment: .leading, spacing: 8) {
            if config.hasPlacedCenter {
                LabeledContent("Center") {
                    Text("\(Int(config.center.x)), \(Int(config.center.y))")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            pixelField("Size", value: Binding(
                get: { config.size },
                set: { config.size = max(10, $0) }
            ), step: 5)
        }
    }

    private var lineFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            if config.hasPlacedCenter {
                LabeledContent("Start") {
                    Text("\(Int(config.startPoint.x)), \(Int(config.startPoint.y))")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                LabeledContent("End") {
                    Text("\(Int(config.endPoint.x)), \(Int(config.endPoint.y))")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var speedField: some View {
        stepperField("Duration", value: Binding(
            get: { config.speed },
            set: { config.speed = max(0.1, $0) }
        ), step: 0.5, format: .number.precision(.fractionLength(1)), unit: "sec")
    }

    private var startingClickField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Starting click", isOn: Binding(
                get: { appState.startingClick },
                set: { appState.startingClick = $0 }
            ))
            Text("Clicks once at the starting point so the window beneath receives focus.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Reusable Fields

    private func pixelField(_ label: String, value: Binding<Double>, step: Double) -> some View {
        stepperField(label, value: Binding(
            get: { (value.wrappedValue * 2).rounded() / 2 },
            set: { value.wrappedValue = ($0 * 2).rounded() / 2 }
        ), step: step, format: .number.precision(.fractionLength(0)), unit: "px")
    }

    private func stepperField(_ label: String, value: Binding<Double>, step: Double, format: FloatingPointFormatStyle<Double>, unit: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
            Spacer()
            TextField("", value: value, format: format)
                .frame(width: 55)
                .multilineTextAlignment(.trailing)
            Stepper("", value: value, step: step)
                .labelsHidden()
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .leading)
        }
    }
}
