import SwiftUI
import Combine

@main
struct FlashCardsApp: App {
    @StateObject private var vocabularyStore: VocabularyStore
    @StateObject private var practiceStore: PracticeStore
    @StateObject private var topicProgressStore: TopicProgressStore
    @StateObject private var topicSessionStore: TopicSessionStore
    @StateObject private var autoSaveCoordinator: AutoSaveCoordinator

    init() {
        let vocabStore = VocabularyStore()
        let practiceStore = PracticeStore(storageKey: "flashcard-practice", requiredCorrectStreak: 5)
        let progressStore = TopicProgressStore()
        let sessionStore = TopicSessionStore()
        let autoSave = AutoSaveCoordinator()
        autoSave.bind(practiceStore: practiceStore,
                      topicProgressStore: progressStore,
                      topicSessionStore: sessionStore)

        _vocabularyStore = StateObject(wrappedValue: vocabStore)
        _practiceStore = StateObject(wrappedValue: practiceStore)
        _topicProgressStore = StateObject(wrappedValue: progressStore)
        _topicSessionStore = StateObject(wrappedValue: sessionStore)
        _autoSaveCoordinator = StateObject(wrappedValue: autoSave)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(practiceStore: practiceStore)
                .environmentObject(vocabularyStore)
                .environmentObject(topicProgressStore)
                .environmentObject(topicSessionStore)
                .environmentObject(autoSaveCoordinator)
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
