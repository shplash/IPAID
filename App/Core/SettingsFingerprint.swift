import Foundation

enum IPASettingsFingerprint {

    static func make(_ modifications: IPAModifications) -> String {
        var hasher = Hasher()

        hasher.add(modifications.trimmedBundleIdentifier)
        hasher.add(modifications.trimmedDisplayName)
        hasher.add(modifications.trimmedMarketingVersion)
        hasher.add(modifications.trimmedBuildNumber)
        hasher.add(modifications.trimmedURLScheme)

        for root in modifications.removedExtensions.sorted() {
            hasher.add("extension")
            hasher.add(root)
        }

        if let icon = modifications.icon {
            hasher.add("icon")
            hasher.add(icon.imageName)
            hasher.add(iconFilesDigest(icon.files))
        }

        for key in modifications.plistOverrides.values.keys.sorted() {
            hasher.add("override")
            hasher.add(key)
            hasher.add(modifications.plistOverrides.values[key])
        }

        for key in modifications.plistOverrides.removedKeys.sorted() {
            hasher.add("removed")
            hasher.add(key)
        }

        return String(hasher.value, radix: 16)
    }

    static func iconFilesDigest(_ files: [String: Data]) -> String {
        var hasher = Hasher()

        for path in files.keys.sorted() {
            hasher.add(path)
            hasher.add(files[path] ?? Data())
        }

        return String(hasher.value, radix: 16)
    }

    private struct Hasher {
        private var state: UInt64 = 0xcbf2_9ce4_8422_2325
        private let prime: UInt64 = 0x0000_0100_0000_01b3

        var value: UInt64 {
            state
        }

        mutating func add(_ text: String) {
            add(Data(text.utf8))
        }

        mutating func add(_ data: Data) {
            var length = UInt64(data.count)

            for _ in 0..<8 {
                mix(UInt8(truncatingIfNeeded: length))
                length >>= 8
            }

            var local = state

            data.withUnsafeBytes { buffer in
                for byte in buffer {
                    local ^= UInt64(byte)
                    local = local &* prime
                }
            }

            state = local
        }

        mutating func add(_ value: PlistValue?) {
            guard let value else {
                add("nil")
                return
            }

            switch value {
            case let .string(text):
                add("s")
                add(text)

            case let .bool(flag):
                add("b")
                add(flag ? "1" : "0")

            case let .integer(number):
                add("i")
                add(String(number))

            case let .real(number):
                add("r")
                add(String(number.bitPattern))

            case let .date(date):
                add("d")
                add(String(date.timeIntervalSinceReferenceDate.bitPattern))

            case let .data(data):
                add("x")
                add(data)

            case let .array(values):
                add("a")
                add(String(values.count))

                for item in values {
                    add(item)
                }

            case let .dictionary(values):
                add("m")
                add(String(values.count))

                for key in values.keys.sorted() {
                    add(key)
                    add(values[key])
                }
            }
        }

        private mutating func mix(_ byte: UInt8) {
            state ^= UInt64(byte)
            state = state &* prime
        }
    }
}
