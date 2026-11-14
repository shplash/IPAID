import SwiftUI
import UIKit

extension View {
    func cardStyle() -> some View {
        self
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
    }
}

struct IPASheet<Content: View>: View {
    private let title: String
    private let onClose: () -> Void
    private let content: Content

    init(
        title: String,
        onClose: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.onClose = onClose
        self.content = content()
    }

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text(title)
                        .font(.title3.weight(.bold))

                    Spacer()

                    Button("Done", action: onClose)
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 10)

                ScrollView {
                    VStack(spacing: 16) {
                        content
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 28)
                }
            }
        }
    }
}

struct IPASectionTitle: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)

            Text(title)
                .font(.headline.weight(.bold))
        }
    }
}

struct IPAFieldBox<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct IPAMetadataRow: View {
    let label: String
    let value: String
    var monospaced = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .font(monospaced ? .system(.subheadline, design: .monospaced) : .subheadline)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .truncationMode(.middle)
        }
        .padding(.vertical, 9)
    }
}

struct IPASubtleDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.055))
            .frame(height: 1)
    }
}

struct IPAIconThumbnail: View {
    let image: UIImage?
    let caption: String
    var size: CGFloat = 64

    var body: some View {
        VStack(spacing: 7) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.high)
                } else {
                    ZStack {
                        Color.secondary.opacity(0.12)
                        Image(systemName: "app")
                            .font(.system(size: size * 0.34, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))

            Text(caption)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct IPAInfoBanner: View {
    let message: String
    var color: Color = .orange
    var icon = "exclamationmark.circle.fill"

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)

            Text(message)
                .font(.subheadline)
                .foregroundColor(color)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(13)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct IPAToolRow: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(width: 26)

                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.secondary.opacity(0.6))
            }
            .contentShape(Rectangle())
            .padding(.vertical, 15)
        }
        .buttonStyle(.plain)
    }
}

struct IPAFileCountRow: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text("\(count)")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(count == 0 ? .secondary : color)
                .ipaidMonospacedDigits()
        }
        .padding(.vertical, 8)
    }
}

struct IPAPathList: View {
    let paths: [String]
    var limit = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(paths.prefix(limit)), id: \.self) { path in
                Text(path)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if paths.count > limit {
                Text("+ \(paths.count - limit) more")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}
