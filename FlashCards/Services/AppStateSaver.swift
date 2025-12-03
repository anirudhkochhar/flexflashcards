import Foundation

struct AppStateSnapshot: Codable {
    let savedAt: Date
    let practiceStates: [String: PracticeCardState]
    let topicProgressStates: [String: TopicProgressState]
    let topicSessionSnapshots: [String: FlashcardRunSnapshot]
}

enum AppStateSaver {
    private static let stateFolderName = "FlashCardsState"
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

        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folderURL = documentsURL.appendingPathComponent(stateFolderName, isDirectory: true)
        if fileManager.fileExists(atPath: folderURL.path) {
            try fileManager.removeItem(at: folderURL)
        }
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let fileURL = folderURL.appendingPathComponent(stateFileName)
        try data.write(to: fileURL, options: .atomic)
        return folderURL
    }

    static func load() throws -> AppStateSnapshot {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL
            .appendingPathComponent(stateFolderName, isDirectory: true)
            .appendingPathComponent(stateFileName)
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        return try decoder.decode(AppStateSnapshot.self, from: data)
    }
}
