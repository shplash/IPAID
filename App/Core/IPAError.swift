import Foundation

enum IPAError: LocalizedError, Equatable {
    case unreadableArchive
    case missingInfoPlist
    case invalidInfoPlist
    case missingEntry(String)
    case invalidBundleIdentifier
    case exportFailed(String)
    case validationFailed([String])

    var errorDescription: String? {
        switch self {
        case .unreadableArchive:
            return "This file is not a valid IPA or ZIP archive."
        case .missingInfoPlist:
            return "Could not find Payload/App.app/Info.plist."
        case .invalidInfoPlist:
            return "The Info.plist could not be read."
        case let .missingEntry(path):
            return "The archive is missing \(path)."
        case .invalidBundleIdentifier:
            return "The app has no valid bundle identifier."
        case let .exportFailed(message):
            return message
        case let .validationFailed(problems):
            return problems.joined(separator: "\n")
        }
    }
}
