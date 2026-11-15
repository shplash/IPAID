import SwiftUI
import UIKit

struct FileBrowserView: View {
    let ipaURL: URL
    let onClose: () -> Void

    @StateObject private var model = FileBrowserModel()
    @State private var shareItem: BrowserShareItem?
    @State private var errorMessage: String?
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: 16) {
                        if let message = errorMessage ?? model.error {
                            IPAInfoBanner(
                                message: message,
                                color: .red,
                                onDismiss: {
                                    errorMessage = nil
                                    model.clearError()
                                }
                            )
                        }

                        if model.items.isEmpty {
                            Text("This folder is empty.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(24)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                        } else {
                            fileList
                        }

                        Text(model.footer)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 28)
                    .ipaidMeasureHeight()
                }
            }
        }
        .onPreferenceChange(IPASheetHeightKey.self) { height in
            contentHeight = height
        }
        .ipaidSheetHeight(contentHeight)
        .onAppear {
            model.load(ipaURL)
        }
        .sheet(item: $shareItem) { item in
            ActivityView(activityItems: [item.url])
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            if !model.path.isEmpty {
                Button {
                    model.goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            Text(model.title)
                .font(.title2.weight(.bold))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            if model.isExtracting {
                ProgressView()
                    .scaleEffect(0.8)
            }

            Button("Done", action: onClose)
                .font(.body.weight(.semibold))
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var fileList: some View {
        VStack(spacing: 0) {
            ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    IPASubtleDivider()
                }

                row(for: item)
            }
        }
        .cardStyle()
    }

    private func row(for item: BrowserItem) -> some View {
        Button {
            errorMessage = nil

            if item.isDirectory {
                model.open(item)
                return
            }

            model.extract(item) { result in
                switch result {
                case let .success(url):
                    shareItem = BrowserShareItem(url: url)
                case let .failure(error):
                    errorMessage = error.localizedDescription
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon(for: item))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(item.isDirectory ? .blue : .secondary)
                    .frame(width: 24)

                Text(item.name)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 10)

                if item.isDirectory {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.secondary.opacity(0.6))
                } else {
                    Text(IPAFormatting.fileSize(item.size))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .ipaidMonospacedDigits()
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private func icon(for item: BrowserItem) -> String {
        if item.isDirectory {
            return "folder.fill"
        }

        switch (item.name as NSString).pathExtension.lowercased() {
        case "plist":
            return "list.bullet.rectangle"
        case "png", "jpg", "jpeg", "car":
            return "photo"
        case "strings":
            return "text.alignleft"
        case "dylib", "framework":
            return "shippingbox"
        default:
            return "doc"
        }
    }
}

struct BrowserItem: Identifiable {
    let path: String
    let name: String
    let isDirectory: Bool
    let size: Int64

    var id: String {
        path
    }
}

struct BrowserShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

final class FileBrowserModel: ObservableObject {
    @Published private(set) var path = ""
    @Published private(set) var items: [BrowserItem] = []
    @Published private(set) var isExtracting = false
    @Published private(set) var error: String?

    private var archive: IPAArchive?
    private var baseDirectory: URL?
    private var directories: Set<String> = []
    private var files: [String: IPAEntry] = [:]

    var title: String {
        if path.isEmpty {
            return "IPA Contents"
        }

        let components = path.split(separator: "/").map(String.init)
        return components.last ?? "IPA Contents"
    }

    var footer: String {
        path.isEmpty ? "" : path
    }

    func load(_ url: URL) {
        guard archive == nil else { return }

        do {
            let archive = try IPAArchive(url: url)
            self.archive = archive
            baseDirectory = url.deletingLastPathComponent()
            files = [:]

            for entry in archive.entries where entry.kind != .directory {
                files[entry.path] = entry
                addParentDirectories(of: entry.path)
            }

            for entry in archive.entries where entry.kind == .directory {
                directories.insert(entry.path)
                addParentDirectories(of: entry.path)
            }

            refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func open(_ item: BrowserItem) {
        guard item.isDirectory else { return }
        path = item.path
        refresh()
    }

    func clearError() {
        error = nil
    }

    func goBack() {
        guard !path.isEmpty else { return }

        var components = path.split(separator: "/").map(String.init)
        components.removeLast()

        path = components.isEmpty ? "" : components.joined(separator: "/") + "/"
        refresh()
    }

    func extract(_ item: BrowserItem, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let archive else {
            completion(.failure(SimpleError("The IPA is no longer open.")))
            return
        }

        isExtracting = true

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let name = (item.name as NSString).lastPathComponent

                guard !name.isEmpty,
                      name != ".",
                      name != "..",
                      !name.contains("/") else {
                    throw SimpleError("This file has a name that cannot be extracted safely.")
                }

                let data = try archive.data(at: item.path)
                let directory = (self.baseDirectory ?? FileManager.default.temporaryDirectory)
                    .appendingPathComponent("Extracted", isDirectory: true)

                try FileManager.default.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true
                )

                let destination = directory.appendingPathComponent(name)
                try? FileManager.default.removeItem(at: destination)
                try data.write(to: destination)

                DispatchQueue.main.async {
                    self.isExtracting = false
                    completion(.success(destination))
                }
            } catch {
                DispatchQueue.main.async {
                    self.isExtracting = false
                    completion(.failure(error))
                }
            }
        }
    }

    private func addParentDirectories(of path: String) {
        var components = path.split(separator: "/").map(String.init)

        if path.hasSuffix("/") {
            if !components.isEmpty {
                components.removeLast()
            }
        } else {
            components.removeLast()
        }

        while !components.isEmpty {
            directories.insert(components.joined(separator: "/") + "/")
            components.removeLast()
        }
    }

    private func refresh() {
        let childDirectories = directories.filter { directory in
            guard directory.hasPrefix(path) else { return false }

            let remainder = directory.dropFirst(path.count).dropLast()
            return !remainder.isEmpty && !remainder.contains("/")
        }

        let childFiles = files.values.filter { entry in
            guard entry.path.hasPrefix(path) else { return false }

            let remainder = entry.path.dropFirst(path.count)
            return !remainder.isEmpty && !remainder.contains("/")
        }

        var result: [BrowserItem] = []

        for directory in childDirectories {
            let name = directory
                .dropLast()
                .split(separator: "/")
                .last
                .map(String.init) ?? directory

            result.append(
                BrowserItem(
                    path: directory,
                    name: name,
                    isDirectory: true,
                    size: 0
                )
            )
        }

        for entry in childFiles {
            result.append(
                BrowserItem(
                    path: entry.path,
                    name: (entry.path as NSString).lastPathComponent,
                    isDirectory: false,
                    size: Int64(entry.uncompressedSize)
                )
            )
        }

        items = result.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory
            }

            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
}
