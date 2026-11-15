import Foundation

enum PlistValue: Equatable {
    case string(String)
    case bool(Bool)
    case integer(Int)
    case real(Double)
    case date(Date)
    case data(Data)
    case array([PlistValue])
    case dictionary([String: PlistValue])

    var typeName: String {
        switch self {
        case .string: return "String"
        case .bool: return "Boolean"
        case .integer: return "Integer"
        case .real: return "Number"
        case .date: return "Date"
        case .data: return "Data"
        case .array: return "Array"
        case .dictionary: return "Dictionary"
        }
    }

    var isEditableText: Bool {
        switch self {
        case .string, .integer, .real:
            return true
        default:
            return false
        }
    }

    var displayText: String {
        switch self {
        case let .string(value):
            return value
        case let .bool(value):
            return value ? "Yes" : "No"
        case let .integer(value):
            return String(value)
        case let .real(value):
            return String(value)
        case let .date(value):
            return ISO8601DateFormatter().string(from: value)
        case let .data(value):
            return "\(value.count) bytes"
        case let .array(values):
            return values.isEmpty ? "Empty" : "\(values.count) items"
        case let .dictionary(values):
            return values.isEmpty ? "Empty" : "\(values.count) keys"
        }
    }

    init?(any value: Any) {
        switch value {
        case let value as String:
            self = .string(value)
        case let value as NSNumber:
            if String(cString: value.objCType) == "c" {
                self = .bool(value.boolValue)
            } else if value.doubleValue == value.doubleValue.rounded(),
                      value.doubleValue >= Double(Int.min),
                      value.doubleValue <= Double(Int.max) {
                self = .integer(value.intValue)
            } else {
                self = .real(value.doubleValue)
            }
        case let value as Int:
            self = .integer(value)
        case let value as Double:
            self = .real(value)
        case let value as Date:
            self = .date(value)
        case let value as Data:
            self = .data(value)
        case let value as [Any]:
            var items: [PlistValue] = []
            for element in value {
                guard let converted = PlistValue(any: element) else { return nil }
                items.append(converted)
            }
            self = .array(items)
        case let value as [String: Any]:
            var items: [String: PlistValue] = [:]
            for (key, element) in value {
                guard let converted = PlistValue(any: element) else { return nil }
                items[key] = converted
            }
            self = .dictionary(items)
        default:
            return nil
        }
    }

    var anyValue: Any {
        switch self {
        case let .string(value): return value
        case let .bool(value): return value
        case let .integer(value): return value
        case let .real(value): return value
        case let .date(value): return value
        case let .data(value): return value
        case let .array(values): return values.map(\.anyValue)
        case let .dictionary(values):
            return values.mapValues(\.anyValue)
        }
    }
}

struct InfoPlistOverrides: Equatable {
    var values: [String: PlistValue] = [:]
    var removedKeys: Set<String> = []

    var isEmpty: Bool {
        values.isEmpty && removedKeys.isEmpty
    }

    var changeCount: Int {
        values.count + removedKeys.count
    }

    mutating func set(_ value: PlistValue, for key: String) {
        removedKeys.remove(key)
        values[key] = value
    }

    mutating func remove(_ key: String) {
        values.removeValue(forKey: key)
        removedKeys.insert(key)
    }

    mutating func reset(_ key: String) {
        values.removeValue(forKey: key)
        removedKeys.remove(key)
    }

    func apply(to dictionary: inout [String: Any]) {
        for key in removedKeys {
            dictionary.removeValue(forKey: key)
        }

        for (key, value) in values {
            dictionary[key] = value.anyValue
        }
    }
}

enum ProtectedPlistKeys {
    static let all: Set<String> = [
        "CFBundleIdentifier",
        "CFBundleExecutable",
        "CFBundlePackageType",
        "CFBundleShortVersionString",
        "CFBundleVersion"
    ]

    static func isProtected(_ key: String) -> Bool {
        all.contains(key) || key.hasPrefix("CFBundleIcons")
    }
}
