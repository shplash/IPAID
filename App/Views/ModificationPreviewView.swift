import SwiftUI
import UIKit

struct ModificationPreviewView: View {
    let summary: IPAModificationSummary
    let originalIcon: UIImage?
    let replacementIcon: UIImage?
    let isExporting: Bool
    let onExport: () -> Void
    let onClose: () -> Void

    @State private var showsIconFiles = false

    private var hasIconChange: Bool {
        summary.changes.contains { $0.id == "icon" }
    }

    private var iconFiles: [String] {
        summary.iconFilePaths
    }

    private var otherAddedFiles: [String] {
        summary.addedFiles.filter { !iconFiles.contains($0) }
    }

    private var otherModifiedFiles: [String] {
        summary.modifiedFiles.filter { !iconFiles.contains($0) }
    }

    private var modifiedCount: Int {
        otherModifiedFiles.count + (iconFiles.isEmpty ? 0 : 1)
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
        IPASheet(title: "Review Changes", centeredTitle: true) {
            VStack(spacing: 12) {
                actionRow

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

                if modifiedCount > 0 || !otherAddedFiles.isEmpty || !summary.removedFiles.isEmpty {
                    filesCard
                }

                ForEach(warnings, id: \.self) { message in
                    IPAInfoBanner(message: message, color: .orange)
                }
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button(action: onClose) {
                Text("Cancel")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .ipaidBorderedButton(.red)

            Button(action: onExport) {
                HStack(spacing: 8) {
                    if isExporting {
                        ProgressView()
                            .accentColor(.white)
                    }

                    Text(isExporting ? "Exporting…" : "Export")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .ipaidProminentButton(.green)
            .disabled(isExporting || summary.isEmpty)
        }
    }

    private var iconCard: some View {
        HStack(alignment: .top, spacing: 18) {
            IPAIconThumbnail(image: originalIcon, caption: "Original", size: 64)

            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(height: 64)

            IPAIconThumbnail(image: replacementIcon, caption: "Replacement", size: 64)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    private var changesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            IPACardHeader(icon: "square.and.pencil", title: "Changes")

            ForEach(Array(summary.changes.enumerated()), id: \.element.id) { index, change in
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
        .cardStyle()
    }

    private var filesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            IPACardHeader(icon: "doc.on.doc", title: "Files")

            IPAFileCountRow(label: "Added", count: otherAddedFiles.count, color: .green)
            IPAFileCountRow(label: "Removed", count: summary.removedFiles.count, color: .red)
            IPAFileCountRow(label: "Modified", count: modifiedCount, color: .orange)

            if !otherAddedFiles.isEmpty {
                listSection(title: "Added")
                IPAPathList(paths: otherAddedFiles, limit: 5)
                    .padding(.top, 4)
            }

            if !summary.removedFiles.isEmpty {
                listSection(title: "Removed")
                IPAPathList(paths: summary.removedFiles, limit: 5)
                    .padding(.top, 4)
            }

            if modifiedCount > 0 {
                listSection(title: "Modified")

                VStack(alignment: .leading, spacing: 4) {
                    if !iconFiles.isEmpty {
                        iconFileRow
                    }

                    if !otherModifiedFiles.isEmpty {
                        IPAPathList(paths: otherModifiedFiles, limit: 5)
                    }
                }
                .padding(.top, 2)
            }
        }
        .cardStyle()
    }

    private var iconFileRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showsIconFiles.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text("App Icon")
                        .font(.subheadline)
                        .foregroundColor(.primary)

                    Spacer(minLength: 8)

                    Text(iconFiles.count == 1 ? "1 file" : "\(iconFiles.count) files")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Image(systemName: showsIconFiles ? "chevron.up" : "chevron.down")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            if showsIconFiles {
                IPAPathList(paths: iconFiles, limit: iconFiles.count)
                    .padding(.bottom, 6)
            }
        }
    }

    private func listSection(title: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            IPASubtleDivider()
                .padding(.vertical, 6)

            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundColor(.secondary)
        }
    }
}
