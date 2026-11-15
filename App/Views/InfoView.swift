import SwiftUI
import UIKit

struct InfoView: View {
    let currentVersion: String
    let currentBuild: String
    @Binding var appearanceMode: String
    @Binding var exportSuffix: String
    @Binding var skipReview: Bool

    @State private var isCheckingForUpdate = false
    @State private var updateAlert: UpdateAlert?

    private let githubURL = URL(string: "https://github.com/shplash/IPAID")!
    private let reportIssueURL = URL(
        string: "https://github.com/shplash/IPAID/issues/new?template=bug_report.yml"
    )!
    private let featureRequestURL = URL(
        string: "https://github.com/shplash/IPAID/issues/new?template=feature_request.yml"
    )!
    private let supportURL = URL(string: "https://ko-fi.com/shplash")!

    var body: some View {
        infoContentCard
            .alert(item: $updateAlert) { alert in
                if let url = alert.url {
                    return Alert(
                        title: Text(alert.title),
                        message: Text(alert.message),
                        primaryButton: .default(Text("View Update")) {
                            UIApplication.shared.open(url)
                        },
                        secondaryButton: .cancel()
                    )
                }

                return Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
    }

    private var infoContentCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Appearance", icon: "circle.lefthalf.filled")

            appearanceControl
                .padding(.top, 15)
                .padding(.bottom, 4)

            skipReviewRow
                .padding(.top, 14)

            subtleDivider
                .padding(.top, 14)

            exportSuffixField
                .padding(.top, 14)

            subtleDivider
                .padding(.top, 30)

            sectionHeader("Links", icon: "link")
                .padding(.top, 28)
                .padding(.bottom, 4)

            infoRow(title: "GitHub", icon: "chevron.left.forwardslash.chevron.right") {
                UIApplication.shared.open(githubURL)
            }

            subtleDivider

            infoRow(
                title: "Check for Updates",
                icon: "arrow.clockwise",
                trailingProgress: isCheckingForUpdate
            ) {
                checkForUpdates()
            }
            .disabled(isCheckingForUpdate)

            subtleDivider
                .padding(.top, 6)

            infoRow(title: "Support Me", icon: "heart") {
                UIApplication.shared.open(supportURL)
            }
            .foregroundColor(.primary)

            subtleDivider
                .padding(.top, 6)

            sectionHeader("Feedback", icon: "bubble.left.and.bubble.right")
                .padding(.top, 30)
                .padding(.bottom, 4)

            infoRow(title: "Report a Bug", icon: "ladybug") {
                UIApplication.shared.open(reportIssueURL)
            }

            subtleDivider

            infoRow(title: "Request a Feature", icon: "lightbulb") {
                UIApplication.shared.open(featureRequestURL)
            }

            subtleDivider
                .padding(.top, 6)

            sectionHeader("Credits", icon: "person.crop.circle")
                .padding(.top, 30)
                .padding(.bottom, 2)

            Text("Developed by shplash")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 12)

            Text(appVersionText)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 2)

            Text("Built with SwiftUI and ZIPFoundation")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 2)

            subtleDivider
                .padding(.top, 24)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var appVersionText: String {
        currentBuild.isEmpty
            ? "Version \(currentVersion)"
            : "Version \(currentVersion) (build \(currentBuild))"
    }

    private var skipReviewRow: some View {
        Toggle(isOn: $skipReview) {
            HStack(spacing: 13) {
                settingIcon("forward.end.fill")

                Text("Skip Review Changes")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: .blue))
    }

    private func settingIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 17, weight: .medium))
            .foregroundColor(.white)
            .frame(width: 26)
    }

    private var exportSuffixField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 13) {
                settingIcon("tag.fill")

                Text("Exported Filename Suffix")
                    .font(.subheadline.weight(.semibold))
            }

            IPAFieldBox {
                HStack(spacing: 8) {
                    TextField(IPAFormatting.defaultExportSuffix, text: $exportSuffix)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)

                    if !exportSuffix.isEmpty {
                        Button {
                            exportSuffix = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.leading, 39)

            Text("Added to exported IPA filenames. Leave it empty for none.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 39)
        }
    }

    private var appearanceControl: some View {
        HStack(spacing: 0) {
            appearanceButton("System", value: "system")
            appearanceButton("Light", value: "light")
            appearanceButton("Dark", value: "dark")
        }
        .padding(4)
        .background(Color.primary.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private func appearanceButton(_ title: String, value: String) -> some View {
        Button {
            guard appearanceMode != value else { return }
            appearanceMode = value
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(appearanceMode == value ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            appearanceMode == value
                                ? Color.primary.opacity(0.11)
                                : Color.clear
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var subtleDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.055))
            .frame(height: 1)
            .padding(.leading, 44)
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.blue)
                .frame(width: 26)

            Text(title)
                .font(.headline.weight(.bold))
        }
    }

    private func infoRow(
        title: String,
        icon: String,
        trailingProgress: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 26)

                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)

                Spacer()

                if trailingProgress {
                    ProgressView()
                        .ipaidSmallControl()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.secondary.opacity(0.55))
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 17)
        }
        .buttonStyle(.plain)
    }

    private func checkForUpdates() {
        guard !isCheckingForUpdate else { return }

        isCheckingForUpdate = true

        var request = URLRequest(
            url: URL(string: "https://api.github.com/repos/shplash/IPAID/releases/latest")!
        )
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("IPAID", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, response, _ in
            guard let data,
                  let httpResponse = response as? HTTPURLResponse,
                  200..<300 ~= httpResponse.statusCode,
                  let release = try? JSONDecoder().decode(GitHubRelease.self, from: data) else {
                DispatchQueue.main.async {
                    isCheckingForUpdate = false
                    updateAlert = UpdateAlert(
                        title: "Couldn't Check for Updates",
                        message: "Please check your internet connection and try again."
                    )
                }
                return
            }

            let latestVersion = release.tagName
                .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))

            DispatchQueue.main.async {
                isCheckingForUpdate = false

                if compareVersions(latestVersion, currentVersion) > 0,
                   let url = URL(string: release.htmlURL) {
                    updateAlert = UpdateAlert(
                        title: "Update Available",
                        message: "IPAID \(latestVersion) is available. You're running \(currentVersion).",
                        url: url
                    )
                } else {
                    updateAlert = UpdateAlert(
                        title: "You're Up to Date",
                        message: "IPAID \(currentVersion) is the latest release."
                    )
                }
            }
        }
        .resume()
    }

    private func compareVersions(_ lhs: String, _ rhs: String) -> Int {
        let left = versionNumbers(lhs)
        let right = versionNumbers(rhs)
        let count = max(left.count, right.count)

        for index in 0..<count {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0

            if l > r { return 1 }
            if l < r { return -1 }
        }

        return 0
    }

    private func versionNumbers(_ version: String) -> [Int] {
        version
            .split(separator: ".")
            .map { component in
                Int(component.prefix { $0.isNumber }) ?? 0
            }
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}

private struct UpdateAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let url: URL?

    init(title: String, message: String, url: URL? = nil) {
        self.title = title
        self.message = message
        self.url = url
    }
}
