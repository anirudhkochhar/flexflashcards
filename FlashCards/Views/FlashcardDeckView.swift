import SwiftUI

enum CardOrientation: String, CaseIterable, Identifiable {
    case germanToEnglish = "DE → EN"
    case englishToGerman = "EN → DE"

    var id: String { rawValue }
    var description: String { rawValue }
}

struct FlashcardDeckView: View {
    let entries: [VocabularyEntry]
    @ObservedObject var practiceStore: PracticeStore

    var body: some View {
        NavigationView {
            FlashcardSessionView(entries: entries, practiceStore: practiceStore)
                .navigationTitle("Flashcards")
        }
    }
}

struct FlashcardSessionView: View {
    let entries: [VocabularyEntry]
    @ObservedObject var practiceStore: PracticeStore

    @State private var currentIndex: Int = 0
    @State private var showAnswer: Bool = false
    @State private var orientation: CardOrientation = .germanToEnglish

    var body: some View {
        VStack(spacing: 16) {
                if let entry = currentEntry {
                    FlashcardView(entry: entry, orientation: orientation, showAnswer: showAnswer)
                        .frame(maxWidth: .infinity, minHeight: 240)
                        .onTapGesture { withAnimation { showAnswer.toggle() } }
                        .animation(.easeInOut, value: showAnswer)

                    HStack {
                        Button(action: { addToPractice(entry) }) {
                            Label(practiceStore.isActive(entry) ? "Already Practicing" : "I got it wrong", systemImage: "exclamationmark.circle")
                        }
                        .disabled(practiceStore.isActive(entry))
                        .buttonStyle(.bordered)

                        Button(action: { primaryAction(for: entry) }) {
                            Label(showAnswer ? "Next" : "Show answer",
                                  systemImage: showAnswer ? "arrow.right.circle" : "eye")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                Text("No cards to show.")
                    .foregroundColor(.secondary)
            }

            Picker("Orientation", selection: $orientation) {
                ForEach(CardOrientation.allCases) { orientation in
                    Text(orientation.description).tag(orientation)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Spacer()
        }
        .padding()
        .onAppear { prepareDeck() }
    }

    private var currentEntry: VocabularyEntry? {
        guard !entries.isEmpty else { return nil }
        return entries[currentIndex % entries.count]
    }

    private func prepareDeck() {
        guard !entries.isEmpty else { return }
        currentIndex = Int.random(in: 0..<entries.count)
        showAnswer = false
    }

    private func nextCard() {
        guard !entries.isEmpty else { return }
        currentIndex = (currentIndex + 1) % entries.count
        showAnswer = false
    }

    private func addToPractice(_ entry: VocabularyEntry) {
        practiceStore.markWrong(for: entry)
    }

    private func primaryAction(for entry: VocabularyEntry) {
        if showAnswer {
            nextCard()
        } else {
            withAnimation {
                showAnswer = true
            }
        }
    }
}

private struct FlashcardView: View {
    let entry: VocabularyEntry
    let orientation: CardOrientation
    let showAnswer: Bool

    var body: some View {
        VStack(spacing: 12) {
            Text(promptTitle)
                .font(.headline)
                .foregroundColor(.secondary)
            Text(questionText)
                .font(.title)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .padding()
            if showAnswer {
                Text(answerText)
                    .font(.title2)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            if showAnswer, orientation == .englishToGerman, let plural = entry.plural {
                Text("Plural: \(plural)")
                    .foregroundColor(.secondary)
            } else if showAnswer, orientation == .germanToEnglish, let plural = entry.plural {
                Text("Plural: \(plural)")
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .padding()
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)).shadow(radius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                .foregroundColor(.accentColor.opacity(0.4))
        )
    }

    private var questionText: String {
        switch orientation {
        case .germanToEnglish:
            return entry.german
        case .englishToGerman:
            return entry.english
        }
    }

    private var answerText: String {
        switch orientation {
        case .germanToEnglish:
            return entry.english
        case .englishToGerman:
            return entry.german
        }
    }

    private var promptTitle: String {
        switch orientation {
        case .germanToEnglish:
            return showAnswer ? "English" : "German"
        case .englishToGerman:
            return showAnswer ? "German" : "English"
        }
    }
}
