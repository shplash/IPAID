import SwiftUI

struct FileTextEditorView: View {
    let edit: BrowserFileEdit
    let onSave: (Data) -> Void
    let onClose: () -> Void

    @State private var text: String
    @State private var errorMessage: String?

    init(
        edit: BrowserFileEdit,
        onSave: @escaping (Data) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.edit = edit
        self.onSave = onSave
        self.onClose = onClose
        _text = State(initialValue: edit.text)
    }

    private var isChanged: Bool {
        text != edit.text
    }

    var body: some View {
        IPASheet(title: edit.name, onClose: onClose, sizesToContent: false) {
            VStack(alignment: .leading, spacing: 12) {
                if let errorMessage {
                    IPAInfoBanner(message: errorMessage, color: .red)
                }

                Text(edit.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)

                TextEditor(text: $text)
                    .font(.system(.footnote, design: .monospaced))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .frame(minHeight: 260)
                    .padding(8)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                HStack(spacing: 10) {
                    Button(action: onClose) {
                        Text("Cancel")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                    }
                    .ipaidGlassButton(.red)

                    Button(action: save) {
                        Text("Save")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                    }
                    .ipaidGlassButton(.green)
                    .disabled(!isChanged)
                }

                Text("Saved changes are included when you export.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .cardStyle()
        }
    }

    private func save() {
        guard let data = TextFileEditing.encode(text) else {
            errorMessage = "This file is too large to save."
            return
        }

        onSave(data)
        onClose()
    }
}
