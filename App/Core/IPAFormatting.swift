import Foundation

enum IPAFormatting {

    static func fileSize(_ bytes: Int64) -> String {
        guard bytes > 0 else {
            return "Unknown"
        }

        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true

        return formatter.string(fromByteCount: bytes)
    }

    static func fileSize(_ bytes: Int) -> String {
        fileSize(Int64(bytes))
    }

    static func fileSize(of url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let size = values.fileSize else {
            return 0
        }

        return Int64(size)
    }

    static func middleTruncated(_ text: String, limit: Int) -> String {
        guard text.count > limit, limit > 8 else {
            return text
        }

        let keep = max(4, (limit - 1) / 2)

        return "\(text.prefix(keep))…\(text.suffix(keep))"
    }

    static let defaultExportSuffix = "-ipaid"

    static func exportSuffix(_ suffix: String) -> String {
        let trimmed = suffix.trimmingCharacters(in: .whitespacesAndNewlines)
        let forbidden = CharacterSet(charactersIn: "/\\:*?\"<>|")
            .union(.newlines)

        return String(trimmed.unicodeScalars.filter { !forbidden.contains($0) })
    }

    static func exportFileName(originalFileName: String, suffix: String) -> String {
        let base = originalFileName.isEmpty
            ? "IPA"
            : URL(fileURLWithPath: originalFileName).deletingPathExtension().lastPathComponent

        let name = base.isEmpty ? "IPA" : base
        let clean = exportSuffix(suffix)

        guard !clean.isEmpty, !name.hasSuffix(clean) else {
            return "\(name).ipa"
        }

        return "\(name)\(clean).ipa"
    }
}
