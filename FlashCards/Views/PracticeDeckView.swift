import SwiftUI

struct PracticeDeckView: View {
    enum PracticeMode: String, CaseIterable, Identifiable {
        case flashcards = "Flashcards"
        case multipleChoice = "Multiple Choice"

        var id: String { rawValue }
    }

    let entries: [VocabularyEntry]
    @ObservedObject var practiceStore: PracticeStore

    @State private var mode: PracticeMode = .flashcards

    private var practiceEntries: [VocabularyEntry] {
        practiceStore.activeEntries(from: entries)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Picker("Practice mode", selection: $mode) {
                    ForEach(PracticeMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text("Practice cards: \(practiceEntries.count)")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if practiceEntries.isEmpty {
                    VStack(spacing: 12) {
                        Text("No practice cards yet")
                            .font(.title3)
                        Text("Mark tough words from the Flashcards or Topics tabs, or miss an answer in Multiple Choice, to build this list.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    switch mode {
                    case .flashcards:
                        PracticeFlashcardSessionView(entries: practiceEntries, practiceStore: practiceStore)
                    case .multipleChoice:
                        PracticeMultipleChoiceSessionView(entries: practiceEntries, practiceStore: practiceStore)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("Practice")
        }
    }
}

private struct PracticeFlashcardSessionView: View {
    let entries: [VocabularyEntry]
    @ObservedObject var practiceStore: PracticeStore

    @State private var showAnswer = false
    @State private var currentIndex: Int?
    @State private var remainingIndices: [Int] = []
    @State private var entriesSignature: String = ""

    var body: some View {
        if let entry = currentEntry {
            VStack(spacing: 16) {
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
            }
            .onChange(of: entriesSignatureValue) { _ in
                syncDeck()
            }
            .onAppear { syncDeck() }
        }
    }

    private var currentEntry: VocabularyEntry? {
        guard let idx = currentIndex, entries.indices.contains(idx) else { return nil }
        return entries[idx]
    }

    private var entriesSignatureValue: String {
        entries.map(\.id).joined(separator: "|")
    }

    private func syncDeck() {
        if entries.isEmpty {
            currentIndex = nil
            remainingIndices = []
            showAnswer = false
            entriesSignature = ""
            return
        }
        let newSignature = entriesSignatureValue
        if newSignature != entriesSignature || currentIndex == nil {
            entriesSignature = newSignature
            remainingIndices = Array(entries.indices).shuffled()
            currentIndex = remainingIndices.isEmpty ? nil : remainingIndices.removeFirst()
            showAnswer = false
        }
    }

    private func advance() {
        guard !entries.isEmpty else { return }
        if remainingIndices.isEmpty {
            remainingIndices = Array(entries.indices).shuffled()
        }
        currentIndex = remainingIndices.removeFirst()
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

    private func reset() {
        currentIndex = nil
        remainingIndices = []
        showAnswer = false
        syncDeck()
    }

    private func progressLabel(for entry: VocabularyEntry) -> String {
        let state = practiceStore.states[entry.id] ?? .empty
        return "Correct streak: \(state.correctStreak)/\(practiceStore.goalStreak)"
    }
}

private struct PracticeMultipleChoiceSessionView: View {
    let entries: [VocabularyEntry]
    @ObservedObject var practiceStore: PracticeStore

    var body: some View {
        MultipleChoiceSessionView(entries: entries,
                                  practiceStore: practiceStore,
                                  allowsPoolSelection: false)
    }
}
