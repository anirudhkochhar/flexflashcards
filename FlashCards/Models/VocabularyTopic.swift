import Foundation

struct VocabularyTopic: Identifiable, Hashable {
    let id: String
    let name: String
    let entries: [VocabularyEntry]
    let sourceURL: URL?

    init(name: String, entries: [VocabularyEntry], sourceURL: URL?) {
        self.id = VocabularyTopic.makeIdentifier(name: name, sourceURL: sourceURL)
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

    private static func makeIdentifier(name: String, sourceURL: URL?) -> String {
        if let sourceURL = sourceURL {
            return "user-\(sourceURL.standardizedFileURL.path)"
        } else {
            return "bundle-\(name.lowercased())"
        }
    }
}
