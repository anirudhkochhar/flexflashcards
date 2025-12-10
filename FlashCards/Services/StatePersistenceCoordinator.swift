import Foundation
import Combine

enum StatePersistenceError: Error {
    case storesUnavailable
}

final class StatePersistenceCoordinator: ObservableObject {
    @Published private(set) var autoSaveFolderName: String?

    private let bookmarkKey = "state-auto-save-folder-bookmark"
    private let stateFileName = "flashcards_state.json"
    private var autoSaveBookmark: Data?
    private var cancellables: Set<AnyCancellable> = []
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
    private let decoder = JSONDecoder()
    private let fileQueue = DispatchQueue(label: "state-persistence-queue", qos: .utility)
    private weak var practiceStore: PracticeStore?
    private weak var topicProgressStore: TopicProgressStore?
    private weak var vocabularyStore: VocabularyStore?

    init() {
        autoSaveBookmark = UserDefaults.standard.data(forKey: bookmarkKey)
        refreshAutoSaveFolderName()
    }

    func bind(practiceStore: PracticeStore,
              topicProgressStore: TopicProgressStore,
              vocabularyStore: VocabularyStore) {
        cancellables.removeAll()
        self.practiceStore = practiceStore
        self.topicProgressStore = topicProgressStore
        self.vocabularyStore = vocabularyStore

        let autoSaveHandler = { [weak self] in
            self?.autoSave()
        }

        practiceStore.$states
            .dropFirst()
            .sink { _ in autoSaveHandler() }
            .store(in: &cancellables)

        topicProgressStore.$states
            .dropFirst()
            .sink { _ in autoSaveHandler() }
            .store(in: &cancellables)

        vocabularyStore.$topics
            .dropFirst()
            .sink { _ in autoSaveHandler() }
            .store(in: &cancellables)
    }

    func manualSave(to folderURL: URL) throws -> URL {
        guard let practiceStore, let topicProgressStore, let vocabularyStore else {
            throw StatePersistenceError.storesUnavailable
        }
        return try writeSnapshot(toFolder: folderURL,
                                 practiceStore: practiceStore,
                                 topicProgressStore: topicProgressStore,
                                 vocabularyStore: vocabularyStore)
    }

    func manualLoad(from url: URL) throws -> AppStateSnapshot {
        let fileURL: URL
        if url.isDirectory {
            fileURL = url.appendingPathComponent(stateFileName)
        } else {
            fileURL = url
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(AppStateSnapshot.self, from: data)
    }

    func setAutoSaveFolder(_ folderURL: URL) throws {
        guard let practiceStore, let topicProgressStore, let vocabularyStore else {
            throw StatePersistenceError.storesUnavailable
        }
        let bookmark = try folderURL.bookmarkData(options: [],
                                                  includingResourceValuesForKeys: nil,
                                                  relativeTo: nil)
        let previousBookmark = autoSaveBookmark
        autoSaveBookmark = bookmark
        do {
            _ = try writeSnapshot(toFolder: folderURL,
                                  practiceStore: practiceStore,
                                  topicProgressStore: topicProgressStore,
                                  vocabularyStore: vocabularyStore)
            UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
            refreshAutoSaveFolderName(with: folderURL)
        } catch {
            autoSaveBookmark = previousBookmark
            if let previousBookmark {
                UserDefaults.standard.set(previousBookmark, forKey: bookmarkKey)
            } else {
                UserDefaults.standard.removeObject(forKey: bookmarkKey)
            }
            refreshAutoSaveFolderName()
            throw error
        }
    }

    func clearAutoSaveFolder() {
        autoSaveBookmark = nil
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        DispatchQueue.main.async {
            self.autoSaveFolderName = nil
        }
    }

    private func autoSave() {
        guard let practiceStore, let topicProgressStore, let vocabularyStore else { return }
        guard let folderURL = resolvedAutoSaveFolderURL() else { return }
        fileQueue.async { [weak self] in
            guard let self = self else { return }
            let needsAccess = folderURL.startAccessingSecurityScopedResource()
            defer {
                if needsAccess {
                    folderURL.stopAccessingSecurityScopedResource()
                }
            }
            do {
                _ = try self.writeSnapshot(toFolder: folderURL,
                                           practiceStore: practiceStore,
                                           topicProgressStore: topicProgressStore,
                                           vocabularyStore: vocabularyStore)
            } catch {
                // Silently ignore auto-save failures; manual save remains available.
            }
        }
    }

    private func writeSnapshot(toFolder folderURL: URL,
                               practiceStore: PracticeStore,
                               topicProgressStore: TopicProgressStore,
                               vocabularyStore: VocabularyStore) throws -> URL {
        let snapshot = makeSnapshot(practiceStore: practiceStore,
                                    topicProgressStore: topicProgressStore,
                                    vocabularyStore: vocabularyStore)
        let data = try encoder.encode(snapshot)
        let fm = FileManager.default
        if !fm.fileExists(atPath: folderURL.path) {
            try fm.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }
        let fileURL = folderURL.appendingPathComponent(stateFileName)
        if fm.fileExists(atPath: fileURL.path) {
            try fm.removeItem(at: fileURL)
        }
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private func resolvedAutoSaveFolderURL() -> URL? {
        guard let bookmark = autoSaveBookmark else { return nil }
        var stale = false
        do {
            let url = try URL(resolvingBookmarkData: bookmark,
                              options: [],
                              relativeTo: nil,
                              bookmarkDataIsStale: &stale)
            if stale {
                clearAutoSaveFolder()
                return nil
            }
            return url
        } catch {
            clearAutoSaveFolder()
            return nil
        }
    }

    private func refreshAutoSaveFolderName(with overrideURL: URL? = nil) {
        let displayURL: URL?
        if let overrideURL = overrideURL {
            displayURL = overrideURL
        } else {
            displayURL = resolvedAutoSaveFolderURL()
        }
        DispatchQueue.main.async {
            self.autoSaveFolderName = displayURL?.lastPathComponent
        }
    }

    private func makeSnapshot(practiceStore: PracticeStore,
                              topicProgressStore: TopicProgressStore,
                              vocabularyStore: VocabularyStore) -> AppStateSnapshot {
        let capture: () -> AppStateSnapshot = {
            let topics = vocabularyStore.topics
            let userTopics = topics
                .filter { $0.sourceURL != nil }
                .map { topic in
                    TopicDataSnapshot(name: topic.name,
                                      entries: topic.entries.map { VocabularyEntrySnapshot(entry: $0) })
                }
            let entrySignatures = topics.flatMap { topic -> [EntrySignatureSnapshot] in
                let isUser = topic.sourceURL != nil
                return topic.entries.map { entry in
                    EntrySignatureSnapshot(entryID: entry.id,
                                           topicName: topic.name,
                                           isUserTopic: isUser,
                                           german: entry.german,
                                           english: entry.english)
                }
            }
            let topicSignatures = topics.map { topic in
                TopicSignatureSnapshot(topicID: topic.id,
                                       topicName: topic.name,
                                       isUserTopic: topic.sourceURL != nil)
            }
            return AppStateSnapshot(savedAt: Date(),
                                    practiceStates: practiceStore.states,
                                    topicProgressStates: topicProgressStore.states,
                                    userTopics: userTopics,
                                    entrySignatures: entrySignatures,
                                    topicSignatures: topicSignatures)
        }
        if Thread.isMainThread {
            return capture()
        } else {
            return DispatchQueue.main.sync(execute: capture)
        }
    }
}

private extension URL {
    var isDirectory: Bool {
        if let resource = try? resourceValues(forKeys: [.isDirectoryKey]),
           let isDirectory = resource.isDirectory {
            return isDirectory
        }
        return hasDirectoryPath
    }
}
