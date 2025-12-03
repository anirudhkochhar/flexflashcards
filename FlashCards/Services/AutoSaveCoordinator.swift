import Foundation
import Combine

final class AutoSaveCoordinator: ObservableObject {
    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: storageKey) }
    }

    private let storageKey = "auto-save-enabled"
    private var cancellables: Set<AnyCancellable> = []

    init() {
        isEnabled = UserDefaults.standard.bool(forKey: storageKey)
    }

    func bind(practiceStore: PracticeStore,
              topicProgressStore: TopicProgressStore,
              topicSessionStore: TopicSessionStore) {
        cancellables.removeAll()

        practiceStore.$states
            .dropFirst()
            .sink { [weak self] _ in
                self?.autoSave(practiceStore: practiceStore,
                               topicProgressStore: topicProgressStore,
                               topicSessionStore: topicSessionStore)
            }
            .store(in: &cancellables)

        topicProgressStore.$states
            .dropFirst()
            .sink { [weak self] _ in
                self?.autoSave(practiceStore: practiceStore,
                               topicProgressStore: topicProgressStore,
                               topicSessionStore: topicSessionStore)
            }
            .store(in: &cancellables)

        topicSessionStore.$snapshots
            .dropFirst()
            .sink { [weak self] _ in
                self?.autoSave(practiceStore: practiceStore,
                               topicProgressStore: topicProgressStore,
                               topicSessionStore: topicSessionStore)
            }
            .store(in: &cancellables)
    }

    private func autoSave(practiceStore: PracticeStore,
                          topicProgressStore: TopicProgressStore,
                          topicSessionStore: TopicSessionStore) {
        guard isEnabled else { return }
        guard let _ = try? AppStateSaver.save(practiceStore: practiceStore,
                                              topicProgressStore: topicProgressStore,
                                              topicSessionStore: topicSessionStore) else { return }
    }
}
