import SwiftUI
import UIKit

struct FileBrowserView: View {
    let ipaURL: URL
    @Binding var editedFiles: [String: Data]
    let onClose: () -> Void

    @StateObject private var model = FileBrowserModel()
    @State private var presentation: BrowserPresentation?
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

                        if !editedFiles.isEmpty {
                            Text(
                                editedFiles.count == 1
                                    ? "1 file edited"
                                    : "\(editedFiles.count) files edited"
                            )
                            .font(.caption)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity, alignment: .center)
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
        .sheet(item: $presentation) { item in
            switch item {
            case let .share(url):
                ActivityView(activityItems: [url])

            case let .edit(edit):
                FileTextEditorView(
                    edit: edit,
                    onSave: { data in
                        editedFiles[edit.path] = data
                    },
                    onClose: { presentation = nil }
                )
            }
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
        Group {
            if item.isDirectory {
                Button {
                    errorMessage = nil
                    model.open(item)
                } label: {
                    HStack(spacing: 8) {
                        leading(for: item)
                        trailing(for: item)
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 6) {
                    Button {
                        openFile(item)
                    } label: {
                        leading(for: item)
                            .contentShape(Rectangle())
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)

                    editControl(for: item)

                    trailing(for: item)
                }
            }
        }
    }

    private func leading(for item: BrowserItem) -> some View {
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

            Spacer(minLength: 4)
        }
    }

    private func editControl(for item: BrowserItem) -> some View {
        Group {
            if item.isEditable {
                Button {
                    beginEdit(item)
                } label: {
                    Text("Edit")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.blue)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 30, alignment: .trailing)
    }

    @ViewBuilder
    private func trailing(for item: BrowserItem) -> some View {
        if item.isDirectory {
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.secondary.opacity(0.6))
                .frame(width: 64, alignment: .trailing)
        } else {
            Text(IPAFormatting.fileSize(item.size))
                .font(.footnote)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(width: 64, alignment: .trailing)
                .ipaidMonospacedDigits()
        }
    }

    private func openFile(_ item: BrowserItem) {
        errorMessage = nil

        model.extract(item) { result in
            switch result {
            case let .success(url):
                presentation = .share(url)
            case let .failure(error):
                errorMessage = error.localizedDescription
            }
        }
    }

    private func beginEdit(_ item: BrowserItem) {
        errorMessage = nil

        if let pending = editedFiles[item.path] {
            guard let text = TextFileEditing.decode(pending) else {
                errorMessage = "This file cannot be edited as text."
                return
            }

            presentation = .edit(
                BrowserFileEdit(path: item.path, name: item.name, text: text)
            )
            return
        }

        do {
            presentation = .edit(
                BrowserFileEdit(
                    path: item.path,
                    name: item.name,
                    text: try model.text(of: item)
                )
            )
        } catch {
            errorMessage = error.localizedDescription
        }
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
    var isEditable: Bool = false

    var id: String {
        path
    }
}

struct BrowserFileEdit: Identifiable {
    let id = UUID()
    let path: String
    let name: String
    let text: String
}

enum BrowserPresentation: Identifiable {
    case share(URL)
    case edit(BrowserFileEdit)

    var id: String {
        switch self {
        case let .share(url):
            return "share-\(url.absoluteString)"
        case let .edit(edit):
            return "edit-\(edit.id)"
        }
    }
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
    private var editability: [String: Editability] = [:]

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
            editability = [:]

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

    func text(of item: BrowserItem) throws -> String {
        guard let archive else {
            throw SimpleError("The IPA is no longer open.")
        }

        if let cached = editability[item.path] {
            switch cached {
            case let .editable(text):
                return text
            case .notEditable:
                throw SimpleError("This file cannot be edited as text.")
            }
        }

        let data = try archive.data(at: item.path)

        guard let text = TextFileEditing.decode(data) else {
            editability[item.path] = .notEditable
            throw SimpleError("This file cannot be edited as text.")
        }

        editability[item.path] = .editable(text)

        return text
    }

    private enum Editability {
        case editable(String)
        case notEditable
    }

    private func isEditable(_ entry: IPAEntry) -> Bool {
        if let cached = editability[entry.path] {
            if case .editable = cached {
                return true
            }

            return false
        }

        let result = inspect(entry)
        editability[entry.path] = result

        if case .editable = result {
            return true
        }

        return false
    }

    private func inspect(_ entry: IPAEntry) -> Editability {
        guard let archive else {
            return .notEditable
        }

        guard entry.kind == .file else {
            return .notEditable
        }

        guard TextFileEditing.isEditablePath(entry.path) else {
            return .notEditable
        }

        guard entry.uncompressedSize > 0,
              entry.uncompressedSize <= TextFileEditing.maximumEditableSize else {
            return .notEditable
        }

        guard let data = try? archive.data(at: entry.path),
              let text = TextFileEditing.decode(data) else {
            return .notEditable
        }

        return .editable(text)
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
                    size: Int64(entry.uncompressedSize),
                    isEditable: isEditable(entry)
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
