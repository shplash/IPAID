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
    private let onClose: (() -> Void)?
    private let centeredTitle: Bool
    private let sizesToContent: Bool
    private let scrolls: Bool
    private let content: Content

    @State private var contentHeight: CGFloat = 0

    init(
        title: String,
        onClose: (() -> Void)? = nil,
        centeredTitle: Bool = false,
        sizesToContent: Bool = true,
        scrolls: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.onClose = onClose
        self.centeredTitle = centeredTitle
        self.sizesToContent = sizesToContent
        self.scrolls = scrolls
        self.content = content()
    }

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if scrolls {
                    ScrollView {
                        contentStack
                            .ipaidMeasureHeight()
                    }
                } else {
                    contentStack
                        .frame(maxHeight: .infinity)
                }
            }
        }
        .onPreferenceChange(IPASheetHeightKey.self) { height in
            contentHeight = height
        }
        .ipaidSheetHeight(sizesToContent ? contentHeight : 0)
    }

    private var contentStack: some View {
        VStack(spacing: 16) {
            content
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 28)
    }

    private var header: some View {
        HStack {
            if centeredTitle {
                Spacer(minLength: 0)

                Text(title)
                    .font(.title2.weight(.bold))

                Spacer(minLength: 0)
            } else {
                Text(title)
                    .font(.title2.weight(.bold))

                Spacer()

                if let onClose {
                    Button("Done", action: onClose)
                        .font(.body.weight(.semibold))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }
}

struct IPASheetHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

extension View {
    func ipaidSheetHeight(_ height: CGFloat) -> some View {
        modifier(IPASheetSizing(height: height))
    }

    func ipaidMeasureHeight() -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(key: IPASheetHeightKey.self, value: proxy.size.height)
            }
        )
    }
}

struct IPASheetSizing: ViewModifier {
    let height: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *), height > 0 {
            content.presentationDetents([.height(detentHeight)])
        } else {
            content
        }
    }

    private var detentHeight: CGFloat {
        let chrome: CGFloat = 76
        let limit = UIScreen.main.bounds.height * 0.92

        return min(max(height + chrome, 240), limit)
    }
}

struct IPASectionHeader: View {
    let title: String
    var isExpanded: Bool? = nil
    var action: (() -> Void)? = nil
    var topPadding: CGFloat = 8

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    label
                }
                .buttonStyle(.plain)
            } else {
                label
            }
        }
    }

    private var label: some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.footnote.weight(.semibold))
                .foregroundColor(.secondary)

            Spacer(minLength: 0)

            if let isExpanded {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 4)
        .padding(.top, topPadding)
    }
}

struct IPACardHeader: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var trailingText: String? = nil
    var trailingColor: Color = .secondary
    var isExpanded: Bool? = nil
    var tint: Color = .blue

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundColor(.primary)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 8)

            if let trailingText, !trailingText.isEmpty {
                Text(trailingText)
                    .font(.caption)
                    .foregroundColor(trailingColor)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if let isExpanded {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}

struct IPAExpandableCard<Content: View>: View {
    private let icon: String
    private let title: String
    private let subtitle: String?
    private let trailingText: String?
    private let trailingColor: Color
    private let tint: Color
    private let content: Content

    @Binding private var isExpanded: Bool

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        trailingText: String? = nil,
        trailingColor: Color = .secondary,
        tint: Color = .blue,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.trailingText = trailingText
        self.trailingColor = trailingColor
        self.tint = tint
        self._isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                IPACardHeader(
                    icon: icon,
                    title: title,
                    subtitle: subtitle,
                    trailingText: trailingText,
                    trailingColor: trailingColor,
                    isExpanded: isExpanded,
                    tint: tint
                )
            }
            .buttonStyle(.plain)

            if isExpanded {
                content
            }
        }
        .cardStyle()
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
    var caption: String? = nil
    var size: CGFloat = 64

    var body: some View {
        VStack(spacing: 7) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fill)
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
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )

            if let caption, !caption.isEmpty {
                Text(caption)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct IPAInfoBanner: View {
    let message: String
    var color: Color = .orange
    var icon = "exclamationmark.circle.fill"
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)

            Text(message)
                .font(.subheadline)
                .foregroundColor(color)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(color.opacity(0.75))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(13)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct IPALoadingRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .scaleEffect(0.8)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer(minLength: 0)
        }
        .padding(13)
        .background(Color.secondary.opacity(0.08))
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

                Spacer(minLength: 8)

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
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if paths.count > limit {
                Text("+ \(paths.count - limit) more")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
