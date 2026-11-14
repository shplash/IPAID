import Foundation

final class IPASession {
    let directory: URL

    var originalURL: URL {
        directory.appendingPathComponent("original.ipa")
    }

    private var outputDirectory: URL {
        directory.appendingPathComponent("Output", isDirectory: true)
    }

    init(directory: URL = IPATemporaryStore.makeSessionDirectory()) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func importIPA(from source: URL) throws -> URL {
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: originalURL.path) {
            try fileManager.removeItem(at: originalURL)
        }

        try fileManager.copyItem(at: source, to: originalURL)
        return originalURL
    }

    func outputURL(for name: String) throws -> URL {
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let base = URL(fileURLWithPath: name)
            .deletingPathExtension()
            .lastPathComponent
        let clean = base.isEmpty ? "Modified" : base

        var candidate = outputDirectory.appendingPathComponent("\(clean).ipa")
        var index = 2

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = outputDirectory.appendingPathComponent("\(clean)-\(index).ipa")
            index += 1
        }

        return candidate
    }

    func clean() {
        try? FileManager.default.removeItem(at: directory)
    }
}

enum IPATemporaryStore {
    static func makeSessionDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("IPAID", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    static func pruneSessions(olderThan age: TimeInterval = 24 * 60 * 60) {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("IPAID", isDirectory: true)

        guard let sessions = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let cutoff = Date().addingTimeInterval(-age)

        for session in sessions {
            let modified = (try? session.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast

            if modified < cutoff {
                try? fileManager.removeItem(at: session)
            }
        }
    }
}
