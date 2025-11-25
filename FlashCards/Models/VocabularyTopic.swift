import Foundation

struct VocabularyTopic: Identifiable, Hashable {
    let id: UUID
    let name: String
    let entries: [VocabularyEntry]
    let sourceURL: URL?

    init(name: String, entries: [VocabularyEntry], sourceURL: URL?) {
        self.id = UUID()
        self.name = name
        self.entries = entries
        self.sourceURL = sourceURL
    }

    var displayName: String {
        name.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var isDeletable: Bool {
        sourceURL != nil
    }
}
