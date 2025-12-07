import SwiftUI

struct MultipleChoiceSessionView: View {
    enum CardPool: String, CaseIterable, Identifiable {
        case all = "Full deck"
        case practice = "Practice"

        var id: String { rawValue }
    }

    let entries: [VocabularyEntry]
    @ObservedObject var practiceStore: PracticeStore
    var allowsPoolSelection: Bool
    var onQuestionFinished: ((VocabularyEntry) -> Void)? = nil

    @State private var pool: CardPool = .all
    @State private var currentQuestion: MultipleChoiceQuestion?
    @State private var selectedAnswer: String?
    @State private var feedback: String?
    @State private var questionCompleted = false
    @State private var queueSignature: String = ""
    @State private var remainingIndices: [Int] = []

    private var poolEntries: [VocabularyEntry] {
        guard allowsPoolSelection else { return entries }
        switch pool {
        case .all:
            return entries
        case .practice:
            let list = practiceStore.activeEntries(from: entries)
            return list.isEmpty ? entries : list
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            if allowsPoolSelection {
                Picker("Pool", selection: $pool) {
                    ForEach(CardPool.allCases) { pool in
                        Text(pool.rawValue).tag(pool)
                    }
                }
                .pickerStyle(.segmented)
            }

            if let question = currentQuestion {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(question.promptLabel)
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(action: { practiceStore.markWrong(for: question.entry) }) {
                            Label("Add to practice", systemImage: "bookmark")
                        }
                        .labelStyle(.iconOnly)
                    }

                    FlexiblePromptText(text: question.prompt)

                    ForEach(question.options, id: \.self) { option in
                        Button(action: { select(option, for: question) }) {
                            HStack {
                                FlexibleOptionText(text: option)
                                Spacer()
                                if selectedAnswer == option {
                                    Image(systemName: option == question.answer ? "checkmark.circle.fill" : "xmark.circle")
                                        .foregroundColor(option == question.answer ? .green : .red)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 12).stroke(selectedAnswer == option ? Color.accentColor : Color.gray.opacity(0.4), lineWidth: 2))
                        .disabled(selectedAnswer != nil)
                    }

                    if let feedback = feedback, let entry = currentQuestion?.entry {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(feedback)
                                .font(.body)
                                .foregroundColor(feedbackColor)
                            let state = practiceStore.states[entry.id] ?? .empty
                            Text("Correct streak: \(state.correctStreak)/\(practiceStore.goalStreak)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Button("Next question") {
                        generateQuestion()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top)
                }
            } else {
                Text("Add more vocabulary to start practicing.")
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .onAppear(perform: generateQuestion)
        .onChange(of: pool) { _ in
            guard allowsPoolSelection else { return }
            generateQuestion()
        }
        .onChange(of: queueKey) { _ in
            remainingIndices.removeAll()
            generateQuestion()
        }
    }

    private var queueKey: String {
        let sourceEntries = allowsPoolSelection ? poolEntries : entries
        return sourceEntries.map(\.id).joined(separator: "|")
    }

    private var feedbackColor: Color {
        guard let question = currentQuestion, let selected = selectedAnswer else { return .primary }
        return selected == question.answer ? .green : .red
    }

    private func select(_ option: String, for question: MultipleChoiceQuestion) {
        guard selectedAnswer == nil else { return }
        selectedAnswer = option
        if !questionCompleted {
            questionCompleted = true
            onQuestionFinished?(question.entry)
        }
        if option == question.answer {
            feedback = "Correct!"
            practiceStore.markCorrect(for: question.entry)
        } else {
            feedback = "Not quite. Correct answer: \(question.answer)"
            practiceStore.markWrong(for: question.entry)
        }
    }

    private func generateQuestion() {
        questionCompleted = false
        selectedAnswer = nil
        feedback = nil
        let availableEntries = allowsPoolSelection ? poolEntries : entries
        syncQueue(for: availableEntries)
        guard let nextIndex = popNextIndex() else {
            currentQuestion = nil
            return
        }
        let entry = availableEntries[nextIndex]
        let orientation: CardOrientation = Bool.random() ? .germanToEnglish : .englishToGerman
        let prompt = orientation == .germanToEnglish ? entry.german : entry.english
        let answer = orientation == .germanToEnglish ? entry.english : entry.german
        let distractors = makeDistractors(for: entry, orientation: orientation, in: availableEntries)
        currentQuestion = MultipleChoiceQuestion(entry: entry,
                                                 orientation: orientation,
                                                 prompt: prompt,
                                                 answer: answer,
                                                 options: (distractors + [answer]).shuffled())
    }

    private func makeDistractors(for entry: VocabularyEntry,
                                 orientation: CardOrientation,
                                 in availableEntries: [VocabularyEntry]? = nil) -> [String] {
        var options = Set<String>()
        options.insert(orientation == .germanToEnglish ? entry.english : entry.german)
        let source = availableEntries ?? entries
        let shuffled = source.shuffled()
        for candidate in shuffled {
            let option = orientation == .germanToEnglish ? candidate.english : candidate.german
            if options.contains(option) { continue }
            options.insert(option)
            if options.count == 4 { break }
        }
        options.remove(orientation == .germanToEnglish ? entry.english : entry.german)
        return Array(options).prefix(3).map { String($0) }
    }

    private func syncQueue(for currentEntries: [VocabularyEntry]) {
        let newSignature = currentEntries.map(\.id).joined(separator: "|")
        if newSignature != queueSignature {
            queueSignature = newSignature
            remainingIndices = Array(currentEntries.indices).shuffled()
        }
        if remainingIndices.isEmpty && !currentEntries.isEmpty {
            remainingIndices = Array(currentEntries.indices).shuffled()
        }
    }

private func popNextIndex() -> Int? {
    guard !remainingIndices.isEmpty else { return nil }
    return remainingIndices.removeFirst()
}
}

private struct FlexiblePromptText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.title2.weight(.semibold))
            .lineLimit(6)
            .minimumScaleFactor(0.8)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct FlexibleOptionText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.body)
            .lineLimit(4)
            .minimumScaleFactor(0.8)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct MultipleChoiceQuestion {
    let entry: VocabularyEntry
    let orientation: CardOrientation
    let prompt: String
    let answer: String
    let options: [String]

    var promptLabel: String {
        orientation == .germanToEnglish ? "Translate to English" : "Translate to German"
    }
}
