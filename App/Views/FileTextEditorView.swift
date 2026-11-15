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
        IPASheet(title: edit.name, onClose: onClose, sizesToContent: false, scrolls: false) {
            VStack(alignment: .leading, spacing: 12) {
                if let errorMessage {
                    IPAInfoBanner(message: errorMessage, color: .red)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(edit.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    TextEditor(text: $text)
                        .font(.system(.footnote, design: .monospaced))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .frame(maxWidth: .infinity, minHeight: 120, maxHeight: .infinity)
                }
                .padding(15)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))

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
