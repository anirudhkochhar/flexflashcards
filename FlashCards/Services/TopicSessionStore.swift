import Foundation

struct FlashcardRunSnapshot: Codable {
    let orderIDs: [String]
    let position: Int
}

final class TopicSessionStore: ObservableObject {
    @Published private(set) var snapshots: [String: FlashcardRunSnapshot]

    private let storageKey = "topic-session-snapshots"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? decoder.decode([String: FlashcardRunSnapshot].self, from: data) {
            snapshots = decoded
        } else {
            snapshots = [:]
        }
    }

    func snapshot(for key: String) -> FlashcardRunSnapshot? {
        snapshots[key]
    }

    func save(snapshot: FlashcardRunSnapshot, for key: String) {
        snapshots[key] = snapshot
        persist()
    }

    func clear(for key: String) {
        if snapshots.removeValue(forKey: key) != nil {
            persist()
        }
    }

    func load(snapshots newSnapshots: [String: FlashcardRunSnapshot]) {
        snapshots = newSnapshots
        persist()
    }

    private func persist() {
        guard let data = try? encoder.encode(snapshots) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
