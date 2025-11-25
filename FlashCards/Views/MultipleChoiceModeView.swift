import SwiftUI

struct MultipleChoiceModeView: View {
    let entries: [VocabularyEntry]
    @ObservedObject var practiceStore: PracticeStore

    var body: some View {
        NavigationView {
            MultipleChoiceSessionView(entries: entries,
                                      practiceStore: practiceStore,
                                      allowsPoolSelection: true)
                .navigationTitle("Multiple Choice")
        }
    }
}

struct MultipleChoiceSessionView: View {
    enum CardPool: String, CaseIterable, Identifiable {
        case all = "Full deck"
        case practice = "Practice"

        var id: String { rawValue }
    }

    let entries: [VocabularyEntry]
    @ObservedObject var practiceStore: PracticeStore
    var allowsPoolSelection: Bool

    @State private var pool: CardPool = .all
    @State private var currentQuestion: MultipleChoiceQuestion?
    @State private var selectedAnswer: String?
    @State private var feedback: String?

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

                    Text(question.prompt)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.leading)

                    ForEach(question.options, id: \.self) { option in
                        Button(action: { select(option, for: question) }) {
                            HStack {
                                Text(option)
                                    .multilineTextAlignment(.leading)
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

                    if let feedback = feedback {
                        Text(feedback)
                            .font(.body)
                            .foregroundColor(feedbackColor)
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
    }

    private var feedbackColor: Color {
        guard let question = currentQuestion, let selected = selectedAnswer else { return .primary }
        return selected == question.answer ? .green : .red
    }

    private func select(_ option: String, for question: MultipleChoiceQuestion) {
        guard selectedAnswer == nil else { return }
        selectedAnswer = option
        if option == question.answer {
            feedback = "Correct!"
            practiceStore.markCorrect(for: question.entry)
        } else {
            feedback = "Not quite. Correct answer: \(question.answer)"
            practiceStore.markWrong(for: question.entry)
        }
    }

    private func generateQuestion() {
        selectedAnswer = nil
        feedback = nil
        guard !poolEntries.isEmpty else {
            currentQuestion = nil
            return
        }
        let entry = poolEntries.randomElement()!
        let orientation: CardOrientation = Bool.random() ? .germanToEnglish : .englishToGerman
        let prompt = orientation == .germanToEnglish ? entry.german : entry.english
        let answer = orientation == .germanToEnglish ? entry.english : entry.german
        let distractors = makeDistractors(for: entry, orientation: orientation)
        currentQuestion = MultipleChoiceQuestion(entry: entry,
                                                 orientation: orientation,
                                                 prompt: prompt,
                                                 answer: answer,
                                                 options: (distractors + [answer]).shuffled())
    }

    private func makeDistractors(for entry: VocabularyEntry, orientation: CardOrientation) -> [String] {
        var options = Set<String>()
        options.insert(orientation == .germanToEnglish ? entry.english : entry.german)
        let shuffled = entries.shuffled()
        for candidate in shuffled {
            let option = orientation == .germanToEnglish ? candidate.english : candidate.german
            if options.contains(option) { continue }
            options.insert(option)
            if options.count == 4 { break }
        }
        options.remove(orientation == .germanToEnglish ? entry.english : entry.german)
        return Array(options).prefix(3).map { String($0) }
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
