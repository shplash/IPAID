import SwiftUI
import UIKit

struct ModificationPreviewView: View {
    let summary: IPAModificationSummary
    let originalIcon: UIImage?
    let replacementIcon: UIImage?
    let isExporting: Bool
    let onExport: () -> Void
    let onClose: () -> Void

    private var hasIconChange: Bool {
        summary.changes.contains { $0.id == "icon" }
    }

    private var warnings: [String] {
        var messages = summary.warnings
        let signature = "Modifying an IPA invalidates its signature. Re-sign it before installing."

        if !messages.contains(signature) {
            messages.append(signature)
        }

        return messages
    }

    var body: some View {
        IPASheet(title: "Review Changes", onClose: onClose) {
            if summary.isEmpty {
                IPAInfoBanner(
                    message: "No changes to export.",
                    color: .secondary,
                    icon: "info.circle"
                )
            }

            if hasIconChange {
                iconCard
            }

            if !summary.changes.isEmpty {
                changesCard
            }

            if !summary.removedFiles.isEmpty ||
                !summary.addedFiles.isEmpty ||
                !summary.modifiedFiles.isEmpty {
                filesCard
            }

            ForEach(warnings, id: \.self) { message in
                IPAInfoBanner(message: message, color: .orange)
            }

            exportCard
        }
    }

    private var iconCard: some View {
        HStack(spacing: 16) {
            IPAIconThumbnail(image: originalIcon, caption: "Original", size: 66)

            Image(systemName: "arrow.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)

            IPAIconThumbnail(image: replacementIcon, caption: "Replacement", size: 66)

            Spacer(minLength: 0)
        }
        .cardStyle()
    }

    private var changesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            IPASectionTitle(icon: "square.and.pencil", title: "Changes")

            ForEach(Array(summary.changes.enumerated()), id: \.element.id) { index, change in
                if index > 0 {
                    IPASubtleDivider()
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(change.label)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)

                    HStack(alignment: .top, spacing: 8) {
                        Text(change.original)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .strikethrough()
                            .lineLimit(2)
                            .truncationMode(.middle)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.top, 3)

                        Text(change.updated)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .truncationMode(.middle)

                        Spacer(minLength: 0)
                    }
                }
                .padding(.vertical, 10)
            }
        }
        .cardStyle()
    }

    private var filesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            IPASectionTitle(icon: "doc.on.doc", title: "Files")

            IPAFileCountRow(label: "Added", count: summary.addedFiles.count, color: .green)
            IPAFileCountRow(label: "Removed", count: summary.removedFiles.count, color: .red)
            IPAFileCountRow(label: "Modified", count: summary.modifiedFiles.count, color: .orange)

            if !summary.addedFiles.isEmpty {
                IPASubtleDivider().padding(.vertical, 6)
                Text("Added")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                IPAPathList(paths: summary.addedFiles, limit: 5)
                    .padding(.top, 4)
            }

            if !summary.removedFiles.isEmpty {
                IPASubtleDivider().padding(.vertical, 6)
                Text("Removed")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                IPAPathList(paths: summary.removedFiles, limit: 5)
                    .padding(.top, 4)
            }

            if !summary.modifiedFiles.isEmpty {
                IPASubtleDivider().padding(.vertical, 6)
                Text("Modified")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                IPAPathList(paths: summary.modifiedFiles, limit: 5)
                    .padding(.top, 4)
            }
        }
        .cardStyle()
    }

    private var exportCard: some View {
        VStack(spacing: 12) {
            Button(action: onExport) {
                HStack {
                    if isExporting {
                        ProgressView()
                            .accentColor(.white)
                    } else {
                        Image(systemName: "arrow.down.doc.fill")
                    }

                    Text(isExporting ? "Exporting…" : "Export IPA")
                        .font(.headline)

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .ipaidProminentButton()
            .disabled(isExporting || summary.isEmpty)

            Button("Cancel", action: onClose)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)

            Text("The original IPA is not modified.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .cardStyle()
    }
}
