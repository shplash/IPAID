import SwiftUI

struct VersionEditorView: View {
    @Binding var marketingVersion: String
    @Binding var buildNumber: String
    let originalVersion: String
    let originalBuild: String
    let references: [IPAVersionReference]
    let onChange: () -> Void
    let onClose: () -> Void

    private var cleanVersion: String {
        marketingVersion.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanBuild: String {
        buildNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var versionChanged: Bool {
        cleanVersion != originalVersion.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var buildChanged: Bool {
        cleanBuild != originalBuild.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var versionError: String {
        versionChanged ? MetadataValidation.marketingVersion(cleanVersion) : ""
    }

    private var buildError: String {
        buildChanged ? MetadataValidation.buildNumber(cleanBuild) : ""
    }

    private var referenceText: String {
        guard let first = references.first else {
            return ""
        }

        let name = first.path
            .split(separator: "/")
            .last
            .map(String.init) ?? first.path

        if references.count == 1 {
            return "The old version also appears in \(name). Only Info.plist is changed."
        }

        return "The old version also appears in \(references.count) bundled files, such as \(name). Only Info.plist is changed."
    }

    var body: some View {
        IPASheet(title: "Version", onClose: onClose) {
            VStack(alignment: .leading, spacing: 12) {
                field(
                    title: "Marketing Version",
                    placeholder: "1.0",
                    text: $marketingVersion,
                    original: originalVersion,
                    error: versionError
                )

                field(
                    title: "Build Number",
                    placeholder: "1",
                    text: $buildNumber,
                    original: originalBuild,
                    error: buildError
                )

                if versionChanged, !references.isEmpty {
                    Text(referenceText)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Only Info.plist is changed.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .cardStyle()
        }
        .onChange(of: marketingVersion) { _ in onChange() }
        .onChange(of: buildNumber) { _ in onChange() }
    }

    private func field(
        title: String,
        placeholder: String,
        text: Binding<String>,
        original: String,
        error: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                if !original.isEmpty {
                    Text("Original \(original)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            IPAFieldBox {
                TextField(placeholder, text: text)
                    .font(.system(.body, design: .monospaced))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }

            if !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct URLEditorView: View {
    @Binding var scheme: String
    let originalScheme: String
    let onChange: () -> Void
    let onClose: () -> Void

    private var cleanScheme: String {
        scheme.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanOriginalScheme: String {
        originalScheme.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var changed: Bool {
        cleanScheme != cleanOriginalScheme
    }

    private var error: String {
        guard changed else {
            return ""
        }

        return MetadataValidation.urlScheme(
            cleanScheme,
            allowEmpty: cleanOriginalScheme.isEmpty
        )
    }

    var body: some View {
        IPASheet(title: "URL Scheme", onClose: onClose) {
            VStack(alignment: .leading, spacing: 12) {
                IPAFieldBox {
                    HStack(spacing: 8) {
                        TextField("myapp", text: $scheme)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)

                        if !scheme.isEmpty {
                            Button {
                                scheme = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Text("Lets links like myapp:// open this app. Links using the old scheme stop working.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if !cleanOriginalScheme.isEmpty {
                    Text("Original \(cleanOriginalScheme)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if !error.isEmpty {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .cardStyle()
        }
        .onChange(of: scheme) { _ in onChange() }
    }
}
