import SwiftUI

struct ComparisonView: View {
    let primaryURL: URL
    let primaryName: String
    let onClose: () -> Void

    @State private var secondaryURL: URL?
    @State private var secondaryName = ""
    @State private var result: IPAComparisonResult?
    @State private var errorMessage: String?
    @State private var isComparing = false
    @State private var showPicker = false

    var body: some View {
        IPASheet(title: "Compare IPAs", onClose: onClose) {
            fileCard

            if isComparing {
                IPALoadingRow(text: "Comparing…")
            }

            if let errorMessage {
                IPAInfoBanner(message: errorMessage, color: .red)
            }

            if let result {
                if !result.hasDifferences {
                    IPAInfoBanner(
                        message: "No differences found.",
                        color: .blue,
                        icon: "checkmark.circle.fill"
                    )
                }

                metadataCard(result)
                filesCard(result)
            }
        }
        .sheet(isPresented: $showPicker) {
            DocumentPicker(
                onPick: { url in
                    showPicker = false
                    secondaryURL = url
                    secondaryName = url.lastPathComponent
                    compare(url)
                },
                onCancel: {
                    showPicker = false
                }
            )
        }
    }

    private var fileCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            IPASectionTitle(icon: "arrow.left.arrow.right", title: "Files")

            IPAMetadataRow(label: "Original", value: primaryName, monospaced: false)

            if let secondaryURL {
                IPASubtleDivider()
                IPAMetadataRow(label: "Compared", value: secondaryURL.lastPathComponent)
            }

            Button {
                showPicker = true
            } label: {
                Label(
                    secondaryURL == nil ? "Select IPA" : "Choose Another IPA",
                    systemImage: "folder"
                )
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
            }
            .ipaidBorderedButton()
        }
        .cardStyle()
    }

    private func metadataCard(_ result: IPAComparisonResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            IPASectionTitle(icon: "app.badge", title: "Metadata")

            ForEach(result.metadata) { item in
                IPASubtleDivider()

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(item.label)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)

                        if item.isDifferent {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 5, height: 5)
                        }
                    }

                    HStack(alignment: .top, spacing: 8) {
                        Text(item.left)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(item.isDifferent ? .primary : .secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(2)
                            .truncationMode(.middle)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.top, 3)

                        Text(item.right)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(item.isDifferent ? .primary : .secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                }
                .padding(.vertical, 10)
            }
        }
        .cardStyle()
    }

    private func filesCard(_ result: IPAComparisonResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            IPASectionTitle(icon: "doc.on.doc", title: "Files")

            IPAFileCountRow(label: "Added", count: result.addedFiles.count, color: .green)
            IPAFileCountRow(label: "Removed", count: result.removedFiles.count, color: .red)
            IPAFileCountRow(label: "Changed", count: result.changedFiles.count, color: .orange)

            if !result.addedFiles.isEmpty {
                IPASubtleDivider().padding(.vertical, 6)
                Text("Added")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                IPAPathList(paths: result.addedFiles, limit: 8)
                    .padding(.top, 4)
            }

            if !result.removedFiles.isEmpty {
                IPASubtleDivider().padding(.vertical, 6)
                Text("Removed")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                IPAPathList(paths: result.removedFiles, limit: 8)
                    .padding(.top, 4)
            }

            if !result.changedFiles.isEmpty {
                IPASubtleDivider().padding(.vertical, 6)
                Text("Changed")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                IPAPathList(paths: result.changedFiles, limit: 8)
                    .padding(.top, 4)
            }
        }
        .cardStyle()
    }

    private func compare(_ url: URL) {
        errorMessage = nil
        result = nil
        isComparing = true

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let primary = try IPAArchive(url: primaryURL)
                let secondary = try IPAArchive(url: url)
                let comparison = IPAComparison.compare(
                    left: primary,
                    leftName: primaryName,
                    right: secondary,
                    rightName: url.lastPathComponent
                )

                DispatchQueue.main.async {
                    result = comparison
                    isComparing = false
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                    isComparing = false
                }
            }
        }
    }
}
