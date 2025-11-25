import Foundation

struct VocabularyTopic: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let entries: [VocabularyEntry]

    init(name: String, entries: [VocabularyEntry]) {
        self.id = UUID()
        self.name = name
        self.entries = entries
    }

    var displayName: String {
        name.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
