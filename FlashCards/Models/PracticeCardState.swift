import Foundation

struct PracticeCardState: Codable {
    var isActive: Bool
    var correctStreak: Int
    var wrongCount: Int

    static let empty = PracticeCardState(isActive: false, correctStreak: 0, wrongCount: 0)
}
