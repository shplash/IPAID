import Foundation

enum ExtensionSelection {

    static func allEnabled(available: [String], removed: Set<String>) -> Bool {
        available.allSatisfy { !removed.contains($0) }
    }

    static func bulkTitle(available: [String], removed: Set<String>) -> String {
        allEnabled(available: available, removed: removed) ? "Disable All" : "Enable All"
    }

    static func bulkSelection(available: [String], removed: Set<String>) -> Set<String> {
        allEnabled(available: available, removed: removed)
            ? Set(available)
            : []
    }

    static func keptCount(available: [String], removed: Set<String>) -> Int {
        available.filter { !removed.contains($0) }.count
    }
}
