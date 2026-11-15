import SwiftUI
import UIKit

struct ModificationPreviewView: View {
    let summary: IPAModificationSummary
    let originalIcon: UIImage?
    let replacementIcon: UIImage?
    let isExporting: Bool
    let onExport: () -> Void
    let onClose: () -> Void

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
            actionRow

            ModificationReviewContent(
                summary: summary,
                originalIcon: originalIcon,
                replacementIcon: replacementIcon
            )

            ForEach(warnings, id: \.self) { message in
                IPAInfoBanner(message: message, color: .orange)
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
            .ipaidGlassButton(.red)

            Button(action: onExport) {
                HStack(spacing: 8) {
                    if isExporting {
                        ProgressView()
                            .accentColor(.green)
                    }

                    Text(isExporting ? "Exporting…" : "Confirm")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .ipaidGlassButton(.green)
            .disabled(isExporting || summary.isEmpty)
        }
    }
}
