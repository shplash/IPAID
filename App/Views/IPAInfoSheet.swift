import SwiftUI
import UIKit

struct IPAInfoSheet: View {
    let info: IPABundleInfo
    let fileName: String
    let iconImage: UIImage?
    let onClose: () -> Void

    @State private var showTechnicalDetails = false

    var body: some View {
        IPASheet(title: "IPA Info", onClose: onClose) {
            overviewCard
            applicationCard
            technicalCard
        }
    }

    private var overviewCard: some View {
        HStack(spacing: 14) {
            IPAIconThumbnail(image: iconImage, size: 62)

            VStack(alignment: .leading, spacing: 4) {
                Text(info.displayName.isEmpty ? "Unnamed App" : info.displayName)
                    .font(.headline)

                Text(info.bundleIdentifier)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(fileName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)
        }
        .cardStyle()
    }

    private var applicationCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            IPACardHeader(icon: "app.badge", title: "Application")

            IPAMetadataRow(label: "Version", value: value(info.marketingVersion))
            IPASubtleDivider()
            IPAMetadataRow(label: "Build", value: value(info.buildNumber))
            IPASubtleDivider()
            IPAMetadataRow(label: "Minimum iOS", value: value(info.minimumOSVersion))
            IPASubtleDivider()
            IPAMetadataRow(
                label: "File size",
                value: IPAFormatting.fileSize(info.fileSize)
            )
            IPASubtleDivider()
            IPAMetadataRow(label: "Extensions", value: "\(info.extensions.count)")
        }
        .cardStyle()
    }

    private var technicalCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showTechnicalDetails.toggle()
                }
            } label: {
                IPACardHeader(
                    icon: "cpu",
                    title: "Technical Details",
                    isExpanded: showTechnicalDetails
                )
            }
            .buttonStyle(.plain)

            if showTechnicalDetails {
                IPASubtleDivider()
                    .padding(.top, 12)

                IPAMetadataRow(
                    label: "Executable",
                    value: value(info.executable),
                    monospaced: true
                )
                IPASubtleDivider()
                IPAMetadataRow(
                    label: "Architectures",
                    value: info.architectures.isEmpty
                        ? "Unknown"
                        : info.architectures.joined(separator: ", "),
                    monospaced: true
                )
                IPASubtleDivider()
                IPAMetadataRow(
                    label: "Devices",
                    value: info.deviceFamilies.isEmpty ? "Unknown" : info.deviceFamilyLabel
                )

                if !info.targetSDK.isEmpty {
                    IPASubtleDivider()
                    IPAMetadataRow(
                        label: "Built with SDK",
                        value: info.targetSDK,
                        monospaced: true
                    )
                }

                IPASubtleDivider()
                IPAMetadataRow(
                    label: "Signed",
                    value: info.isSigned ? "Yes — re-sign after export" : "No"
                )
                IPASubtleDivider()
                IPAMetadataRow(
                    label: "Bundle path",
                    value: info.appRoot,
                    monospaced: true
                )
            }
        }
        .cardStyle()
    }

    private func value(_ text: String) -> String {
        text.isEmpty ? "Unknown" : text
    }
}
