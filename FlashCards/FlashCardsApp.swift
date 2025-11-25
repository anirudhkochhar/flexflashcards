import SwiftUI

@main
struct FlashCardsApp: App {
    @StateObject private var vocabularyStore = VocabularyStore()
    @StateObject private var practiceStore = PracticeStore(storageKey: "flashcard-practice", requiredCorrectStreak: 5)
    @StateObject private var topicProgressStore = TopicProgressStore()

    var body: some Scene {
        WindowGroup {
            ContentView(practiceStore: practiceStore)
                .environmentObject(vocabularyStore)
                .environmentObject(topicProgressStore)
        }
    }
}

final class VocabularyStore: ObservableObject {
    @Published private(set) var topics: [VocabularyTopic] = []
    @Published var loadError: VocabularyLoader.LoaderError?
    private let topicFileManager = TopicFileManager()

    var entries: [VocabularyEntry] {
        topics.flatMap { $0.entries }
    }

    init() {
        loadVocabulary()
    }

    func loadVocabulary() {
        do {
            topics = try VocabularyLoader.loadTopics(userDirectory: topicFileManager.topicsDirectory)
            loadError = nil
        } catch let error as VocabularyLoader.LoaderError {
            switch error {
            case .fileMissing:
                topics = []
                loadError = nil
            default:
                loadError = error
                topics = []
            }
        } catch {
            loadError = .fileMissing
            topics = []
        }
    }

    func importTopics(from url: URL) throws -> TopicImportResult {
        let result = try topicFileManager.importTopics(from: url)
        loadVocabulary()
        return result
    }

    func deleteTopic(_ topic: VocabularyTopic) throws {
        guard let sourceURL = topic.sourceURL else { return }
        try topicFileManager.deleteImportedTopic(at: sourceURL)
        loadVocabulary()
    }
}
