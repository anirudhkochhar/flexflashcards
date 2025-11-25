import SwiftUI

@main
struct FlashCardsApp: App {
    @StateObject private var vocabularyStore = VocabularyStore()
    @StateObject private var flashcardPractice = PracticeStore(storageKey: "flashcard-practice", requiredCorrectStreak: 5)
    @StateObject private var multipleChoicePractice = PracticeStore(storageKey: "multiple-choice-practice", requiredCorrectStreak: 5)

    var body: some Scene {
        WindowGroup {
            ContentView(flashcardPractice: flashcardPractice,
                        multipleChoicePractice: multipleChoicePractice)
                .environmentObject(vocabularyStore)
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
            loadError = error
            topics = []
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
}
