import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ActivityView: UIViewControllerRepresentable {

    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct DocumentPicker: UIViewControllerRepresentable {

    let onPick: (URL) -> Void
    let onCancel: (() -> Void)?

    init(
        onPick: @escaping (URL) -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        self.onPick = onPick
        self.onCancel = onCancel
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.item],
            asCopy: true
        )

        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator

        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {

        let onPick: (URL) -> Void
        let onCancel: (() -> Void)?

        init(onPick: @escaping (URL) -> Void, onCancel: (() -> Void)?) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPicker(
            _ controller: UIDocumentPickerViewController,
            didPickDocumentsAt urls: [URL]
        ) {
            guard let url = urls.first else {
                return
            }

            onPick(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel?()
        }
    }
}
