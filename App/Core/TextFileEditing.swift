import Foundation

enum TextFileEditing {

    static let maximumEditableSize = 512 * 1024

    static let editableExtensions: Set<String> = [
        "plist", "json", "xml", "strings", "stringsdict", "txt",
        "conf", "cfg", "ini", "yaml", "yml", "properties",
        "entitlements", "css", "html", "js", "sh"
    ]

    static func isEditablePath(_ path: String) -> Bool {
        let name = (path as NSString).lastPathComponent

        guard !name.isEmpty, !path.hasSuffix("/") else {
            return false
        }

        return editableExtensions.contains((name as NSString).pathExtension.lowercased())
    }

    static func isExcludedSystemPlist(_ path: String, info: IPABundleInfo) -> Bool {
        if path == info.infoPlistPath {
            return true
        }

        return info.extensions.contains { $0.infoPlistPath == path }
    }

    static func decode(_ data: Data) -> String? {
        guard !data.isEmpty, data.count <= maximumEditableSize else {
            return nil
        }

        guard !data.contains(0) else {
            return nil
        }

        guard let text = String(data: data, encoding: .utf8) else {
            return nil
        }

        return text
    }

    static func encode(_ text: String) -> Data? {
        let data = Data(text.utf8)

        guard data.count <= maximumEditableSize else {
            return nil
        }

        return data
    }
}
