import SwiftUI

struct PracticeDeckView: View {
    let entries: [VocabularyEntry]
    @ObservedObject var practiceStore: PracticeStore

    @State private var showAnswer = false
    @State private var currentIndex = 0

    private var practiceEntries: [VocabularyEntry] {
        let candidates = practiceStore.activeEntries(from: entries)
        guard !candidates.isEmpty else { return [] }
        return candidates
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Practice cards: \(practiceEntries.count)")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let entry = currentEntry {
                    VStack(spacing: 12) {
                        Text(entry.german)
                            .font(.title)
                            .fontWeight(.semibold)
                        if let plural = entry.plural {
                            Text(plural)
                                .foregroundColor(.secondary)
                        }
                        Divider()
                        if showAnswer {
                            Text(entry.english)
                                .font(.title2)
                                .multilineTextAlignment(.center)
                        } else {
                            Text("Tap \"Show answer\" when ready")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color(.systemBackground)))
                    .shadow(radius: 4)

                    Text(progressLabel(for: entry))
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    HStack {
                        Button(showAnswer ? "Hide answer" : "Show answer") {
                            showAnswer.toggle()
                        }
                        .buttonStyle(.bordered)

                        Button("I was right") {
                            markCorrect(entry)
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Still wrong") {
                            markWrong(entry)
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    VStack(spacing: 12) {
                        Text("No practice cards yet")
                            .font(.title3)
                        Text("Mark tough words from the Flashcards tab to build a focused deck.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Practice")
            .onChange(of: practiceEntries.count) { _ in
                currentIndex = 0
                showAnswer = false
            }
        }
    }

    private var currentEntry: VocabularyEntry? {
        guard !practiceEntries.isEmpty else { return nil }
        let index = currentIndex % practiceEntries.count
        return practiceEntries[index]
    }

    private func advance() {
        guard !practiceEntries.isEmpty else { return }
        currentIndex = (currentIndex + 1) % practiceEntries.count
        showAnswer = false
    }

    private func markCorrect(_ entry: VocabularyEntry) {
        practiceStore.markCorrect(for: entry)
        advance()
    }

    private func markWrong(_ entry: VocabularyEntry) {
        practiceStore.markWrong(for: entry)
        advance()
    }

    private func progressLabel(for entry: VocabularyEntry) -> String {
        let state = practiceStore.states[entry.id] ?? .empty
        return "Correct streak: \(state.correctStreak)/\(practiceStore.goalStreak)"
    }
}
