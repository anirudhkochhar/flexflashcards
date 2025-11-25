import Foundation

final class PracticeStore: ObservableObject {
    @Published private(set) var states: [String: PracticeCardState]

    private let storageKey: String
    private let requiredCorrectStreak: Int
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    var goalStreak: Int {
        requiredCorrectStreak
    }

    init(storageKey: String, requiredCorrectStreak: Int) {
        self.storageKey = storageKey
        self.requiredCorrectStreak = requiredCorrectStreak
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? decoder.decode([String: PracticeCardState].self, from: data) {
            self.states = saved
        } else {
            self.states = [:]
        }
    }

    func isActive(_ entry: VocabularyEntry) -> Bool {
        states[entry.id]?.isActive ?? false
    }

    func activeEntries(from entries: [VocabularyEntry]) -> [VocabularyEntry] {
        entries.filter { isActive($0) }
    }

    func markWrong(for entry: VocabularyEntry) {
        var state = states[entry.id] ?? PracticeCardState.empty
        state.isActive = true
        state.correctStreak = 0
        state.wrongCount += 1
        states[entry.id] = state
        persist()
    }

    func markCorrect(for entry: VocabularyEntry) {
        guard var state = states[entry.id] else { return }
        state.correctStreak += 1
        if state.correctStreak >= requiredCorrectStreak {
            state.isActive = false
        }
        states[entry.id] = state
        persist()
    }

    func reset(for entry: VocabularyEntry) {
        states[entry.id] = PracticeCardState.empty
        persist()
    }

    private func persist() {
        guard let encoded = try? encoder.encode(states) else { return }
        UserDefaults.standard.set(encoded, forKey: storageKey)
    }
}
