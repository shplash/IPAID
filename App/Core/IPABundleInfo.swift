import Foundation

struct IPAExtensionInfo: Equatable, Identifiable {
    let root: String
    let infoPlistPath: String
    let bundleIdentifier: String
    let displayName: String

    var id: String {
        root
    }

    var name: String {
        let folder = root
            .split(separator: "/")
            .last { $0.hasSuffix(".appex") }

        let raw = folder.map(String.init) ?? root
        return Self.humanReadable(raw.replacingOccurrences(of: ".appex", with: ""))
    }

    static func humanReadable(_ raw: String) -> String {
        var name = raw

        if name.hasSuffix("Extension") {
            name.removeLast("Extension".count)
        }

        name = name
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")

        var result = ""
        var previousWasLowercaseOrNumber = false

        for character in name {
            let scalar = String(character)
            let isUppercase = scalar.rangeOfCharacter(from: .uppercaseLetters) != nil
            let isNumber = scalar.rangeOfCharacter(from: .decimalDigits) != nil

            if isUppercase && previousWasLowercaseOrNumber && !result.hasSuffix(" ") {
                result.append(" ")
            }

            result.append(character)

            previousWasLowercaseOrNumber =
                scalar.rangeOfCharacter(from: .lowercaseLetters) != nil || isNumber
        }

        let cleaned = result
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? raw : cleaned
    }
}

struct IPABundleInfo: Equatable {
    let appRoot: String
    let infoPlistPath: String
    let bundleIdentifier: String
    let displayName: String
    let bundleName: String
    let marketingVersion: String
    let buildNumber: String
    let minimumOSVersion: String
    let executable: String
    let urlScheme: String
    let extensions: [IPAExtensionInfo]
    let iconPlan: IPAIconPlan
    let architectures: [String]
    let fileSize: Int64

    var executablePath: String {
        executable.isEmpty ? appRoot : appRoot + executable
    }
}

enum IPABundleParsing {

    static func displayName(from dictionary: [String: Any], appRoot: String) -> String {
        if let name = dictionary["CFBundleDisplayName"] as? String, !name.isEmpty {
            return name
        }

        if let name = dictionary["CFBundleName"] as? String, !name.isEmpty {
            return name
        }

        let folder = appRoot.split(separator: "/").dropLast().last.map(String.init) ?? ""
        return folder.replacingOccurrences(of: ".app", with: "")
    }

    static func firstURLScheme(from dictionary: [String: Any]) -> String {
        guard let types = dictionary["CFBundleURLTypes"] as? [[String: Any]] else {
            return ""
        }

        for type in types {
            if let schemes = type["CFBundleURLSchemes"] as? [String],
               let first = schemes.first {
                return first
            }
        }

        return ""
    }

    static func updateURLScheme(
        in dictionary: inout [String: Any],
        scheme: String,
        bundleIdentifier: String
    ) {
        if var types = dictionary["CFBundleURLTypes"] as? [[String: Any]], !types.isEmpty {
            if var schemes = types[0]["CFBundleURLSchemes"] as? [String], !schemes.isEmpty {
                schemes[0] = scheme
                types[0]["CFBundleURLSchemes"] = schemes
            } else {
                types[0]["CFBundleURLSchemes"] = [scheme]
            }
            dictionary["CFBundleURLTypes"] = types
        } else {
            dictionary["CFBundleURLTypes"] = [[
                "CFBundleURLName": bundleIdentifier,
                "CFBundleURLSchemes": [scheme]
            ]]
        }
    }
}
