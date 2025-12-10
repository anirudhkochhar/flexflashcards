import Foundation

struct AppStateSnapshot: Codable {
    let savedAt: Date
    let practiceStates: [String: PracticeCardState]
    let topicProgressStates: [String: TopicProgressState]
    let userTopics: [TopicDataSnapshot]
    let entrySignatures: [EntrySignatureSnapshot]
    let topicSignatures: [TopicSignatureSnapshot]

    init(savedAt: Date,
         practiceStates: [String: PracticeCardState],
         topicProgressStates: [String: TopicProgressState],
         userTopics: [TopicDataSnapshot] = [],
         entrySignatures: [EntrySignatureSnapshot] = [],
         topicSignatures: [TopicSignatureSnapshot] = []) {
        self.savedAt = savedAt
        self.practiceStates = practiceStates
        self.topicProgressStates = topicProgressStates
        self.userTopics = userTopics
        self.entrySignatures = entrySignatures
        self.topicSignatures = topicSignatures
    }

    private enum CodingKeys: String, CodingKey {
        case savedAt
        case practiceStates
        case topicProgressStates
        case userTopics
        case entrySignatures
        case topicSignatures
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        savedAt = try container.decode(Date.self, forKey: .savedAt)
        practiceStates = try container.decode([String: PracticeCardState].self, forKey: .practiceStates)
        topicProgressStates = try container.decode([String: TopicProgressState].self, forKey: .topicProgressStates)
        userTopics = try container.decodeIfPresent([TopicDataSnapshot].self, forKey: .userTopics) ?? []
        entrySignatures = try container.decodeIfPresent([EntrySignatureSnapshot].self, forKey: .entrySignatures) ?? []
        topicSignatures = try container.decodeIfPresent([TopicSignatureSnapshot].self, forKey: .topicSignatures) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(savedAt, forKey: .savedAt)
        try container.encode(practiceStates, forKey: .practiceStates)
        try container.encode(topicProgressStates, forKey: .topicProgressStates)
        try container.encode(userTopics, forKey: .userTopics)
        try container.encode(entrySignatures, forKey: .entrySignatures)
        try container.encode(topicSignatures, forKey: .topicSignatures)
    }
}

struct TopicDataSnapshot: Codable {
    let name: String
    let entries: [VocabularyEntrySnapshot]
}

struct VocabularyEntrySnapshot: Codable {
    let german: String
    let plural: String?
    let english: String

    init(entry: VocabularyEntry) {
        self.german = entry.german
        self.plural = entry.plural
        self.english = entry.english
    }

    func csvValues() -> [String] {
        [german, plural ?? "", english]
    }
}

struct EntrySignatureSnapshot: Codable {
    let entryID: String
    let topicName: String
    let isUserTopic: Bool
    let german: String
    let english: String

    var key: String {
        Self.makeKey(topicName: topicName, isUserTopic: isUserTopic, german: german, english: english)
    }

    static func makeKey(topicName: String, isUserTopic: Bool, german: String, english: String) -> String {
        let topicPart = topicName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let germanPart = german.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let englishPart = english.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let origin = isUserTopic ? "user" : "bundle"
        return "\(origin)|\(topicPart)|\(germanPart)|\(englishPart)"
    }
}

struct TopicSignatureSnapshot: Codable {
    let topicID: String
    let topicName: String
    let isUserTopic: Bool

    var key: String {
        Self.makeKey(name: topicName, isUserTopic: isUserTopic)
    }

    static func makeKey(name: String, isUserTopic: Bool) -> String {
        let topicPart = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let origin = isUserTopic ? "user" : "bundle"
        return "\(origin)|\(topicPart)"
    }
}
