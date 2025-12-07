import Foundation

struct AppStateSnapshot: Codable {
    let savedAt: Date
    let practiceStates: [String: PracticeCardState]
    let topicProgressStates: [String: TopicProgressState]
    let topicSessionSnapshots: [String: FlashcardRunSnapshot]
}

enum AppStateSaver {
    private static let stateFolderNameKey = "state-folder-name"
    private static let defaultFolderName = "FlashCardsState"
    private static let stateFileName = "state.json"

    static func save(practiceStore: PracticeStore,
                     topicProgressStore: TopicProgressStore,
                     topicSessionStore: TopicSessionStore) throws -> URL {
        let snapshot = AppStateSnapshot(savedAt: Date(),
                                        practiceStates: practiceStore.states,
                                        topicProgressStates: topicProgressStore.states,
                                        topicSessionSnapshots: topicSessionStore.snapshots)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)

        let folderURL = makeStateFolderURL()
        if fileManager.fileExists(atPath: folderURL.path) {
            try fileManager.removeItem(at: folderURL)
        }
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let fileURL = folderURL.appendingPathComponent(stateFileName)
        try data.write(to: fileURL, options: .atomic)
        return folderURL
    }

    static func load() throws -> AppStateSnapshot {
        let fileURL = makeStateFolderURL()
            .appendingPathComponent(stateFileName)
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        return try decoder.decode(AppStateSnapshot.self, from: data)
    }

    static var stateFolderName: String {
        UserDefaults.standard.string(forKey: stateFolderNameKey) ?? defaultFolderName
    }

    static func updateStateFolderName(_ name: String) {
        let sanitized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = sanitized.isEmpty ? defaultFolderName : sanitized
        UserDefaults.standard.set(value, forKey: stateFolderNameKey)
    }

    private static var fileManager: FileManager { FileManager.default }

    private static func makeStateFolderURL() -> URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL.appendingPathComponent(stateFolderName, isDirectory: true)
    }
}
