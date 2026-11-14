import Foundation

enum MachOArchitectures {

    static func parse(data: Data) -> [String] {
        let bytes = [UInt8](data.prefix(4096))
        guard bytes.count >= 8 else { return [] }

        let magic = readUInt32(bytes, at: 0, littleEndian: false)

        switch magic {
        case 0xFEEDFACE:
            return thinArchitectures(bytes, littleEndian: false)
        case 0xCEFAEDFE:
            return thinArchitectures(bytes, littleEndian: true)
        case 0xFEEDFACF:
            return thinArchitectures(bytes, littleEndian: false)
        case 0xCFFAEDFE:
            return thinArchitectures(bytes, littleEndian: true)
        case 0xCAFEBABE:
            return fatArchitectures(bytes, littleEndian: false, is64Bit: false)
        case 0xBEBAFECA:
            return fatArchitectures(bytes, littleEndian: true, is64Bit: false)
        case 0xCAFEBABF:
            return fatArchitectures(bytes, littleEndian: false, is64Bit: true)
        case 0xBFBAFECA:
            return fatArchitectures(bytes, littleEndian: true, is64Bit: true)
        default:
            return []
        }
    }

    private static func thinArchitectures(_ bytes: [UInt8], littleEndian: Bool) -> [String] {
        guard bytes.count >= 12 else { return [] }
        let cpuType = readUInt32(bytes, at: 4, littleEndian: littleEndian)
        let cpuSubtype = readUInt32(bytes, at: 8, littleEndian: littleEndian) & 0x00FFFFFF
        return [name(cpuType: cpuType, cpuSubtype: cpuSubtype)]
    }

    private static func fatArchitectures(
        _ bytes: [UInt8],
        littleEndian: Bool,
        is64Bit: Bool
    ) -> [String] {
        guard bytes.count >= 8 else { return [] }

        let count = Int(readUInt32(bytes, at: 4, littleEndian: littleEndian))
        guard count > 0, count < 32 else { return [] }

        let entrySize = is64Bit ? 32 : 20
        var result: [String] = []

        for index in 0..<count {
            let offset = 8 + index * entrySize
            guard offset + 8 <= bytes.count else { break }

            let cpuType = readUInt32(bytes, at: offset, littleEndian: littleEndian)
            let cpuSubtype = readUInt32(bytes, at: offset + 4, littleEndian: littleEndian) & 0x00FFFFFF
            let architecture = name(cpuType: cpuType, cpuSubtype: cpuSubtype)

            if !result.contains(architecture) {
                result.append(architecture)
            }
        }

        return result
    }

    private static func name(cpuType: UInt32, cpuSubtype: UInt32) -> String {
        switch cpuType {
        case 12:
            if cpuSubtype == 9 { return "armv7s" }
            if cpuSubtype == 11 { return "armv7k" }
            return "armv7"
        case 0x0100000C:
            return cpuSubtype == 2 ? "arm64e" : "arm64"
        case 0x01000007:
            return "x86_64"
        case 7:
            return "i386"
        default:
            return "cpu\(cpuType)"
        }
    }

    private static func readUInt32(_ bytes: [UInt8], at offset: Int, littleEndian: Bool) -> UInt32 {
        guard offset + 4 <= bytes.count else { return 0 }

        if littleEndian {
            return UInt32(bytes[offset]) |
                (UInt32(bytes[offset + 1]) << 8) |
                (UInt32(bytes[offset + 2]) << 16) |
                (UInt32(bytes[offset + 3]) << 24)
        }

        return (UInt32(bytes[offset]) << 24) |
            (UInt32(bytes[offset + 1]) << 16) |
            (UInt32(bytes[offset + 2]) << 8) |
            UInt32(bytes[offset + 3])
    }
}
