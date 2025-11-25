import Foundation

struct VocabularyEntry: Identifiable, Codable, Hashable {
    let id: String
    let german: String
    let plural: String?
    let english: String

    init(german: String, plural: String?, english: String) {
        self.german = german.trimmingCharacters(in: .whitespacesAndNewlines)
        self.plural = plural?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        self.english = english.trimmingCharacters(in: .whitespacesAndNewlines)
        self.id = VocabularyEntry.makeIdentifier(german: self.german, english: self.english)
    }

    static func makeIdentifier(german: String, english: String) -> String {
        let normalized = "\(german.lowercased())-\(english.lowercased())"
        return normalized.replacingOccurrences(of: " ", with: "-")
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
