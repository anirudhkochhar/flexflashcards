import Foundation

struct TopicProgressState: Codable {
    var completedCardIDs: Set<String> = []
    var completionCount: Int = 0

    var completedCount: Int {
        completedCardIDs.count
    }
}

final class TopicProgressStore: ObservableObject {
    @Published private(set) var states: [String: TopicProgressState]

    private let storageKey = "topic-progress-store"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? decoder.decode([String: TopicProgressState].self, from: data) {
            states = saved
        } else {
            states = [:]
        }
    }

    func state(for topic: VocabularyTopic, entries: [VocabularyEntry]) -> TopicProgressState {
        normalizeState(for: topic, entries: entries)
        return states[topic.id] ?? TopicProgressState()
    }

    func markCompleted(_ entry: VocabularyEntry, in topic: VocabularyTopic) {
        var state = states[topic.id] ?? TopicProgressState()
        let inserted = state.completedCardIDs.insert(entry.id).inserted
        if inserted {
            states[topic.id] = state
            persist()
        }
    }

    func reset(topic: VocabularyTopic, incrementCompletion: Bool) {
        var state = states[topic.id] ?? TopicProgressState()
        if incrementCompletion {
            state.completionCount += 1
        }
        state.completedCardIDs = []
        states[topic.id] = state
        persist()
    }

    func clear(topic: VocabularyTopic) {
        if states.removeValue(forKey: topic.id) != nil {
            persist()
        }
    }

    private func normalizeState(for topic: VocabularyTopic, entries: [VocabularyEntry]) {
        let validIDs = Set(entries.map(\.id))
        if validIDs.isEmpty {
            if var state = states[topic.id], !state.completedCardIDs.isEmpty {
                state.completedCardIDs = []
                states[topic.id] = state
                persist()
            }
            return
        }
        if var state = states[topic.id] {
            let filtered = state.completedCardIDs.intersection(validIDs)
            if filtered.count != state.completedCardIDs.count {
                state.completedCardIDs = filtered
                states[topic.id] = state
                persist()
            }
        }
    }

    private func persist() {
        guard let data = try? encoder.encode(states) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
