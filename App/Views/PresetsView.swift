import SwiftUI

struct PresetsView: View {
    let info: IPABundleInfo
    let modifications: IPAModifications
    let onApply: (ExportPreset) -> Void
    let onClose: () -> Void

    private let store = ExportPresetStore()

    @State private var presets: [ExportPreset] = []
    @State private var name = ""
    @State private var errorMessage: String?

    init(
        info: IPABundleInfo,
        modifications: IPAModifications,
        onApply: @escaping (ExportPreset) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.info = info
        self.modifications = modifications
        self.onApply = onApply
        self.onClose = onClose
        _presets = State(initialValue: ExportPresetStore().presets())
    }

    var body: some View {
        IPASheet(title: "Export Presets", onClose: onClose) {
            saveCard

            if let errorMessage {
                IPAInfoBanner(message: errorMessage, color: .red)
            }

            presetsCard
        }
    }

    private var saveCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            IPACardHeader(icon: "square.and.arrow.down", title: "Save Current Changes")

            IPAFieldBox {
                TextField("Preset name", text: $name)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }

            Button {
                save()
            } label: {
                Text("Save Preset")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
            }
            .ipaidBorderedButton()
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .cardStyle()
    }

    private var presetsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            IPACardHeader(icon: "slider.horizontal.3", title: "Saved Presets")

            if presets.isEmpty {
                Text("No presets yet.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 12)
            }

            ForEach(presets) { preset in
                IPASubtleDivider()

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(preset.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)

                        Text(settingsLabel(for: preset))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer(minLength: 8)

                    Button("Apply") {
                        onApply(preset)
                        onClose()
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.blue)
                    .buttonStyle(.plain)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())

                    Button {
                        presets = store.remove(preset)
                    } label: {
                        Image(systemName: "trash")
                            .font(.footnote)
                            .foregroundColor(.red)
                            .padding(.vertical, 6)
                            .padding(.leading, 4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 10)
            }
        }
        .cardStyle()
    }

    private func settingsLabel(for preset: ExportPreset) -> String {
        let count = preset.fieldCount

        return count == 1 ? "1 setting" : "\(count) settings"
    }

    private func save() {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !clean.isEmpty else {
            errorMessage = "Enter a preset name."
            return
        }

        let preset = ExportPreset.make(
            from: modifications,
            info: info,
            name: clean,
            availableExtensions: info.extensions
        )

        guard preset.fieldCount > 0 else {
            errorMessage = "Change a setting before saving a preset."
            return
        }

        presets = store.add(
            name: clean,
            from: modifications,
            info: info,
            availableExtensions: info.extensions
        )

        name = ""
        errorMessage = nil
    }
}
