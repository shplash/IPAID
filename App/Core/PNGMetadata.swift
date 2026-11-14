import Foundation

struct PNGMetadata: Equatable {
    let width: Int
    let height: Int
    let bitDepth: Int
    let colorType: Int
    let isComplete: Bool

    var isSquare: Bool {
        width == height
    }

    var hasAlphaChannel: Bool {
        colorType == 4 || colorType == 6
    }

    init?(data: Data) {
        let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        guard data.count >= 33, Array(data.prefix(8)) == signature else {
            return nil
        }

        let bytes = [UInt8](data)
        guard bytes[12] == 0x49, bytes[13] == 0x48, bytes[14] == 0x44, bytes[15] == 0x52 else {
            return nil
        }

        width = Int(Self.readUInt32(bytes, at: 16))
        height = Int(Self.readUInt32(bytes, at: 20))
        bitDepth = Int(bytes[24])
        colorType = Int(bytes[25])
        isComplete = Self.hasCompleteChunks(bytes)

        guard width > 0, height > 0 else {
            return nil
        }
    }

    private static func hasCompleteChunks(_ bytes: [UInt8]) -> Bool {
        var offset = 8
        var sawData = false

        while offset + 12 <= bytes.count {
            let length = Int(readUInt32(bytes, at: offset))
            let typeStart = offset + 4
            let next = typeStart + 4 + length + 4

            guard length >= 0, next <= bytes.count else {
                return false
            }

            let type = String(
                bytes: bytes[typeStart..<(typeStart + 4)],
                encoding: .ascii
            )

            if type == "IDAT" {
                sawData = true
            }

            if type == "IEND" {
                return sawData
            }

            offset = next
        }

        return false
    }

    private static func readUInt32(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        (UInt32(bytes[offset]) << 24) |
        (UInt32(bytes[offset + 1]) << 16) |
        (UInt32(bytes[offset + 2]) << 8) |
        UInt32(bytes[offset + 3])
    }
}
