import SwiftUI

struct AdvancedPlistView: View {
    let info: IPABundleInfo
    let original: [String: Any]
    @Binding var overrides: InfoPlistOverrides
    let onClose: () -> Void

    @State private var editingKey: String?
    @State private var editingText = ""
    @State private var editError = ""
    @State private var newKey = ""
    @State private var newValue = ""
    @State private var newType = PlistEditType.string
    @State private var newBoolean = true
    @State private var addError = ""

    var body: some View {
        IPASheet(title: "Advanced Info.plist", onClose: onClose) {
            IPAInfoBanner(
                message: "These values are written directly to Info.plist. Leave them unchanged unless you know the key.",
                color: .orange
            )

            valuesCard
            addCard
        }
    }

    private var keys: [String] {
        Array(Set(original.keys).union(overrides.values.keys)).sorted()
    }

    private var valuesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            IPACardHeader(icon: "list.bullet.rectangle", title: "Values")

            if keys.isEmpty {
                Text("No values.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 12)
            }

            ForEach(keys, id: \.self) { key in
                IPASubtleDivider()
                row(for: key)
            }
        }
        .cardStyle()
    }

    private func row(for key: String) -> some View {
        let removed = overrides.removedKeys.contains(key)
        let value = overrides.values[key] ?? original[key].flatMap(PlistValue.init(any:))
        let protected = ProtectedPlistKeys.isProtected(key)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(key)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundColor(removed ? .secondary : .primary)
                        .strikethrough(removed)

                    Text(value?.typeName ?? "Unsupported")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 8)

                if protected {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if removed {
                    Button("Undo") {
                        overrides.reset(key)
                    }
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                } else if let value {
                    if case let .bool(current) = value {
                        Toggle(
                            "",
                            isOn: Binding(
                                get: { current },
                                set: { overrides.set(.bool($0), for: key) }
                            )
                        )
                        .labelsHidden()
                    } else if value.isEditableText {
                        Button {
                            beginEditing(key: key, value: value)
                        } label: {
                            Text(value.displayText)
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundColor(.blue)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(value.displayText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            if protected {
                Text("Managed by IPAID.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if editingKey == key {
                editingRow(for: key, value: value)
            }

            if !protected, !removed, value != nil {
                HStack {
                    if overrides.values[key] != nil {
                        Button("Reset") {
                            overrides.reset(key)
                            editingKey = nil
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.blue)
                    }

                    Spacer()

                    Button("Remove") {
                        if original[key] == nil {
                            overrides.reset(key)
                        } else {
                            overrides.remove(key)
                        }

                        editingKey = nil
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func editingRow(for key: String, value: PlistValue?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            IPAFieldBox {
                TextField("Value", text: $editingText)
                    .font(.system(.body, design: .monospaced))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }

            if !editError.isEmpty {
                Text(editError)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            HStack(spacing: 18) {
                Button("Save") {
                    saveEdit(for: key, value: value)
                }
                .font(.footnote.weight(.semibold))
                .foregroundColor(.blue)
                .padding(.vertical, 4)

                Button("Cancel") {
                    editingKey = nil
                    editError = ""
                }
                .font(.footnote.weight(.semibold))
                .foregroundColor(.secondary)
                .padding(.vertical, 4)

                Spacer()
            }
        }
        .padding(.top, 2)
    }

    private var addCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            IPACardHeader(icon: "plus.circle", title: "Add Value")

            IPAFieldBox {
                TextField("Key", text: $newKey)
                    .font(.system(.body, design: .monospaced))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }

            Picker("Type", selection: $newType) {
                ForEach(PlistEditType.allCases, id: \.self) { type in
                    Text(type.title).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())

            if newType == .boolean {
                Toggle("Value", isOn: $newBoolean)
                    .font(.subheadline)
            } else {
                IPAFieldBox {
                    TextField("Value", text: $newValue)
                        .font(.system(.body, design: .monospaced))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
            }

            if !addError.isEmpty {
                Text(addError)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Button {
                addValue()
            } label: {
                Text("Add")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
            }
            .ipaidBorderedButton()
        }
        .cardStyle()
    }

    private func beginEditing(key: String, value: PlistValue) {
        editingKey = key
        editingText = value.displayText
        editError = ""
    }

    private func saveEdit(for key: String, value: PlistValue?) {
        let clean = editingText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch value {
        case .integer:
            guard let number = Int(clean) else {
                editError = "Enter a whole number."
                return
            }
            overrides.set(.integer(number), for: key)
        case .real:
            guard let number = Double(clean) else {
                editError = "Enter a number."
                return
            }
            overrides.set(.real(number), for: key)
        default:
            overrides.set(.string(editingText), for: key)
        }

        editingKey = nil
        editError = ""
    }

    private func addValue() {
        let key = newKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !key.isEmpty else {
            addError = "Enter a key."
            return
        }

        guard !ProtectedPlistKeys.isProtected(key) else {
            addError = "That key is managed by IPAID."
            return
        }

        guard original[key] == nil, overrides.values[key] == nil else {
            addError = "That key already exists."
            return
        }

        switch newType {
        case .string:
            overrides.set(.string(newValue), for: key)
        case .integer:
            guard let number = Int(newValue.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                addError = "Enter a whole number."
                return
            }
            overrides.set(.integer(number), for: key)
        case .boolean:
            overrides.set(.bool(newBoolean), for: key)
        }

        newKey = ""
        newValue = ""
        newBoolean = true
        addError = ""
    }
}

enum PlistEditType: String, CaseIterable {
    case string
    case integer
    case boolean

    var title: String {
        switch self {
        case .string: return "Text"
        case .integer: return "Number"
        case .boolean: return "Toggle"
        }
    }
}
