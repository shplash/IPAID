import Foundation

struct IPAExtensionInfo: Equatable, Identifiable {
    let root: String
    let infoPlistPath: String
    let bundleIdentifier: String
    let displayName: String
    var extensionPointIdentifier: String = ""

    var id: String {
        root
    }

    var name: String {
        Self.displayName(forRoot: root)
    }

    static func displayName(forRoot root: String) -> String {
        let folder = root
            .split(separator: "/")
            .last { $0.hasSuffix(".appex") }

        let raw: String

        if let folder {
            raw = String(folder).replacingOccurrences(of: ".appex", with: "")
        } else {
            raw = URL(fileURLWithPath: root)
                .deletingPathExtension()
                .lastPathComponent
        }

        return humanReadable(raw)
    }

    static func tip(forName name: String, pointIdentifier: String = "") -> String {
        if let point = tip(forPointIdentifier: pointIdentifier) {
            return point
        }

        let lower = name.lowercased()

        if lower.contains("widget") {
            return "Adds Home Screen or Lock Screen widget support. Removing it disables that widget."
        }

        if lower.contains("intent") || lower.contains("siri") {
            return "Handles Siri, Shortcuts, or App Intent actions. Removing it may disable automation features."
        }

        if lower.contains("notification service") {
            return "Handles enhanced notification content, images, or media. Removing it may make notifications more basic."
        }

        if lower.contains("notification content") {
            return "Provides custom notification layouts. Removing it may disable rich notification views."
        }

        if lower.contains("notification") {
            return "Supports notification-related features. Removing it may affect alerts or notification previews."
        }

        if lower.contains("safari") {
            return "Adds Safari integration. Removing it may disable Safari extension features."
        }

        if lower.contains("share") {
            return "Adds Share Sheet integration. Removing it may stop the app appearing in share menus."
        }

        if lower.contains("watch") {
            return "Adds Apple Watch support. Removing it may disable watchOS companion features."
        }

        return "App extension component. Removing it can reduce signing/App ID usage, but some app features may stop working."
    }

    static func tip(forPointIdentifier identifier: String) -> String? {
        switch identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "com.apple.widgetkit-extension":
            return "Adds Home Screen, Lock Screen or StandBy widgets. Removing it disables this app's widgets."

        case "com.apple.widget-extension":
            return "Adds the legacy Today widget, shown when swiping right on the Home Screen."

        case "com.apple.notification-service-extension":
            return "Attaches images and media to notifications. Removing it may make notifications plainer."

        case "com.apple.notification-content-extension":
            return "Draws custom notification layouts. Removing it may disable rich notification views."

        case "com.apple.share-services":
            return "Adds this app to the system Share Sheet. Removing it stops it appearing in share menus."

        case "com.apple.safari.extension", "com.apple.safari.content-blocker":
            return "Adds a Safari extension or content blocker. Removing it disables that feature in Safari."

        case "com.apple.intents-service", "com.apple.intents-ui-service":
            return "Handles Siri, Shortcuts and App Intents. Removing it may disable those actions."

        case "com.apple.keyboard-service":
            return "Adds a custom keyboard. Removing it removes that keyboard from Settings."

        case "com.apple.watchkit-extension":
            return "Adds the watchOS app. Removing it may disable Apple Watch features."

        case "com.apple.background-asset-downloader-extension":
            return "Downloads App Store assets in the background. Removing it may delay first launch."

        case "com.apple.fileprovider-nonui":
            return "Provides files to the Files app. Removing it removes this app's location from Files."

        case "com.apple.callkit.call-directory":
            return "Supplies caller ID to Phone. Removing it stops this app identifying incoming calls."

        case "com.apple.photo-editing":
            return "Adds editing tools to Photos. Removing it removes those tools from the Photos editor."

        case "com.apple.action-extension":
            return "Adds actions to the Share Sheet and Services. Removing it removes those actions."

        case "com.apple.authentication-services-credential-provider-ui":
            return "Provides saved passwords to AutoFill. Removing it stops the app filling passwords elsewhere."

        default:
            return nil
        }
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
