import Foundation

enum MetadataValidation {

    static func bundleIdentifier(_ id: String) -> String {
        let clean = id.trimmingCharacters(in: .whitespacesAndNewlines)

        if clean.isEmpty {
            return "Bundle ID cannot be empty."
        }

        if clean.count > 120 {
            return "Bundle ID is too long."
        }

        if !clean.contains(".") {
            return "Bundle ID must contain at least one dot."
        }

        if clean.contains("..") {
            return "Bundle ID cannot contain two dots in a row."
        }

        let allowed = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-"
        )

        if clean.rangeOfCharacter(from: allowed.inverted) != nil {
            return "Bundle ID contains invalid characters."
        }

        if clean.hasPrefix(".") || clean.hasSuffix(".") {
            return "Bundle ID cannot start or end with a dot."
        }

        return ""
    }

    static func displayName(_ name: String) -> String {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if clean.isEmpty {
            return "Display name cannot be empty."
        }

        if clean.count > 30 {
            return "Display name is too long."
        }

        return ""
    }

    static func urlScheme(_ scheme: String, allowEmpty: Bool) -> String {
        let clean = scheme.trimmingCharacters(in: .whitespacesAndNewlines)

        if clean.isEmpty {
            return allowEmpty ? "" : "URL scheme cannot be empty."
        }

        if clean.count > 100 {
            return "URL scheme is too long."
        }

        if clean.contains("://") || clean.contains("/") || clean.contains(" ") {
            return "URL scheme contains invalid characters."
        }

        let allowed = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+.-"
        )

        if clean.rangeOfCharacter(from: allowed.inverted) != nil {
            return "URL scheme contains invalid characters."
        }

        guard let first = clean.first, first.isLetter else {
            return "URL scheme must start with a letter."
        }

        return ""
    }

    static func marketingVersion(_ version: String) -> String {
        let clean = version.trimmingCharacters(in: .whitespacesAndNewlines)

        if clean.isEmpty {
            return "Marketing version cannot be empty."
        }

        if clean.count > 18 {
            return "Marketing version is too long."
        }

        let parts = clean.split(separator: ".", omittingEmptySubsequences: false)

        if parts.isEmpty || parts.count > 3 {
            return "Marketing version must use up to three numbers separated by dots."
        }

        for part in parts {
            if part.isEmpty || part.count > 9 || part.contains(where: { !$0.isNumber }) {
                return "Marketing version must use numbers separated by dots."
            }
        }

        return ""
    }

    static func buildNumber(_ build: String) -> String {
        let clean = build.trimmingCharacters(in: .whitespacesAndNewlines)

        if clean.isEmpty {
            return "Build number cannot be empty."
        }

        if clean.count > 18 {
            return "Build number is too long."
        }

        let parts = clean.split(separator: ".", omittingEmptySubsequences: false)

        if parts.count > 3 {
            return "Build number must use up to three numbers separated by dots."
        }

        for part in parts {
            if part.isEmpty || part.count > 9 || part.contains(where: { !$0.isNumber }) {
                return "Build number can only contain numbers and dots."
            }
        }

        return ""
    }
}
