import SwiftUI

struct PresetsView: View {
    let info: IPABundleInfo
    let modifications: IPAModifications
    let onApply: (ExportPresetPlan) -> Void
    let onClose: () -> Void

    private let store = ExportPresetStore()

    @State private var presets: [ExportPreset] = []
    @State private var name = ""
    @State private var errorMessage: String?
    @State private var reviewing: ExportPreset?

    init(
        info: IPABundleInfo,
        modifications: IPAModifications,
        onApply: @escaping (ExportPresetPlan) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.info = info
        self.modifications = modifications
        self.onApply = onApply
        self.onClose = onClose
        _presets = State(initialValue: ExportPresetStore().presets())
    }

    var body: some View {
        IPASheet(
            title: reviewing == nil ? "Export Presets" : "Review Preset",
            onClose: onClose
        ) {
            if let preset = reviewing {
                reviewCard(for: preset)
            } else {
                saveCard

                if let errorMessage {
                    IPAInfoBanner(message: errorMessage, color: .red)
                }

                presetsCard
            }
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
                    Button {
                        reviewing = preset
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(preset.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)

                                Text(detail(for: preset))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }

                            Spacer(minLength: 8)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.secondary.opacity(0.6))
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)

                    Button {
                        presets = store.remove(preset)
                    } label: {
                        Image(systemName: "trash")
                            .font(.footnote)
                            .foregroundColor(.red)
                            .padding(.vertical, 8)
                            .padding(.leading, 4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 2)
            }
        }
        .cardStyle()
    }

    private func reviewCard(for preset: ExportPreset) -> some View {
        let plan = preset.plan(applyingTo: modifications, info: info)

        return VStack(alignment: .leading, spacing: 12) {
            IPACardHeader(icon: "slider.horizontal.3", title: preset.name)

            if plan.isEmpty {
                Text("Nothing in this preset changes the current settings.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(plan.changes.enumerated()), id: \.element.id) { index, change in
                        if index > 0 {
                            IPASubtleDivider()
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            Text(change.label)
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.secondary)

                            HStack(alignment: .top, spacing: 8) {
                                Text(change.original)
                                    .font(.system(.footnote, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .strikethrough()
                                    .lineLimit(2)
                                    .truncationMode(.middle)

                                Image(systemName: "arrow.right")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .padding(.top, 3)

                                Text(change.updated)
                                    .font(.system(.footnote, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                    .truncationMode(.middle)

                                Spacer(minLength: 0)
                            }
                        }
                        .padding(.vertical, 10)
                    }
                }
            }

            ForEach(plan.warnings, id: \.self) { warning in
                IPAInfoBanner(message: warning, color: .orange)
            }

            Button {
                onApply(plan)
                onClose()
            } label: {
                Text("Apply Preset")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
            }
            .ipaidProminentButton()
            .disabled(plan.isEmpty)

            Button("Back to Presets") {
                reviewing = nil
            }
            .font(.footnote.weight(.semibold))
            .foregroundColor(.secondary)
        }
        .cardStyle()
    }

    private func detail(for preset: ExportPreset) -> String {
        let count = preset.fieldCount
        let settings = count == 1 ? "1 setting" : "\(count) settings"
        let source = (preset.sourceBundleIdentifier ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        return source.isEmpty ? settings : "\(settings) · from \(source)"
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
