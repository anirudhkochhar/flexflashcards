import SwiftUI

enum CardOrientation: String, CaseIterable, Identifiable {
    case germanToEnglish = "DE → EN"
    case englishToGerman = "EN → DE"

    var id: String { rawValue }
    var description: String { rawValue }
}

struct FlashcardDeckView: View {
    enum StudyMode: String, CaseIterable, Identifiable {
        case flashcards = "Flashcards"
        case multipleChoice = "Multiple Choice"

        var id: String { rawValue }
    }

    let entries: [VocabularyEntry]
    @ObservedObject var practiceStore: PracticeStore

    @State private var mode: StudyMode = .flashcards

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Picker("Study Mode", selection: $mode) {
                    ForEach(StudyMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                switch mode {
                case .flashcards:
                    FlashcardSessionView(entries: entries, practiceStore: practiceStore)
                        .padding(.horizontal)
                case .multipleChoice:
                    MultipleChoiceSessionView(entries: entries,
                                              practiceStore: practiceStore,
                                              allowsPoolSelection: true)
                        .padding(.horizontal)
                }
                Spacer(minLength: 0)
            }
            .navigationTitle("Flashcards")
        }
    }
}

struct FlashcardSessionView: View {
    let entries: [VocabularyEntry]
    @ObservedObject var practiceStore: PracticeStore
    var onCardComplete: ((VocabularyEntry) -> Void)? = nil

    @State private var currentIndex: Int?
    @State private var showAnswer: Bool = false
    @State private var orientation: CardOrientation = .germanToEnglish
    @State private var remainingIndices: [Int] = []
    @State private var entriesSignature: String = ""
    @State private var history: [Int] = []
    @State private var forwardStack: [Int] = []

    var body: some View {
        VStack(spacing: 16) {
                if let entry = currentEntry {
                    FlashcardView(entry: entry, orientation: orientation, showAnswer: showAnswer)
                        .frame(maxWidth: .infinity, minHeight: 240)
                        .onTapGesture {
                            if showAnswer {
                                primaryAction(for: entry)
                            } else {
                                withAnimation { showAnswer = true }
                            }
                        }
                        .animation(.easeInOut, value: showAnswer)
                        .gesture(
                            DragGesture(minimumDistance: 20)
                                .onEnded { value in
                                    if value.translation.width > 60 {
                                        previousCard()
                                    } else if value.translation.width < -60 {
                                        primaryAction(for: entry)
                                    }
                                }
                        )

                    HStack {
                        Button(action: { addToPractice(entry) }) {
                            Label(practiceStore.isActive(entry) ? "Already Practicing" : "I got it wrong", systemImage: "exclamationmark.circle")
                        }
                        .disabled(practiceStore.isActive(entry))
                        .buttonStyle(.bordered)

                        if showAnswer && practiceStore.isActive(entry) {
                            Button(action: {
                                practiceStore.markWrong(for: entry)
                                onCardComplete?(entry)
                                nextCard()
                            }) {
                                Label("Still wrong", systemImage: "xmark.circle")
                            }
                            .buttonStyle(.bordered)
                        }

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
        .onAppear { syncDeckWithEntries(force: true) }
        .onChange(of: entriesSignatureValue) { _ in
            syncDeckWithEntries(force: true)
        }
    }

    private var entriesSignatureValue: String {
        entries.map(\.id).joined(separator: "|")
    }

    private var currentEntry: VocabularyEntry? {
        guard let idx = currentIndex, entries.indices.contains(idx) else { return nil }
        return entries[idx]
    }

    private func syncDeckWithEntries(force: Bool = false) {
        if entries.isEmpty {
            currentIndex = nil
            remainingIndices = []
            showAnswer = false
            entriesSignature = ""
            history = []
            forwardStack = []
            return
        }
        let newSignature = entriesSignatureValue
        if force || newSignature != entriesSignature || currentIndex == nil {
            entriesSignature = newSignature
            remainingIndices = Array(entries.indices).shuffled()
            currentIndex = remainingIndices.isEmpty ? nil : remainingIndices.removeFirst()
            showAnswer = false
            history = []
            forwardStack = []
        }
    }

    private func nextCard() {
        if let forward = forwardStack.popLast() {
            if let current = currentIndex {
                history.append(current)
            }
            currentIndex = forward
            showAnswer = false
            return
        }
        guard !entries.isEmpty else {
            currentIndex = nil
            return
        }
        if let current = currentIndex {
            history.append(current)
            let maxHistory = 50
            if history.count > maxHistory {
                history.removeFirst(history.count - maxHistory)
            }
        }
        if remainingIndices.isEmpty {
            remainingIndices = Array(entries.indices).shuffled()
        }
        currentIndex = remainingIndices.removeFirst()
        forwardStack.removeAll()
        showAnswer = false
    }

    private func addToPractice(_ entry: VocabularyEntry) {
        practiceStore.markWrong(for: entry)
    }

    private func primaryAction(for entry: VocabularyEntry) {
        if showAnswer {
            onCardComplete?(entry)
            nextCard()
        } else {
            withAnimation {
                showAnswer = true
            }
        }
    }

    private func previousCard() {
        guard let previous = history.popLast() else { return }
        if let current = currentIndex {
            forwardStack.append(current)
        }
        currentIndex = previous
        showAnswer = false
    }
}

struct FlashcardView: View {
    let entry: VocabularyEntry
    let orientation: CardOrientation
    let showAnswer: Bool

    var body: some View {
        VStack(spacing: 12) {
            Text(promptTitle)
                .font(.headline)
                .foregroundColor(.secondary)
            AdaptiveText(text: questionText)
                .fontWeight(.semibold)
                .padding()
            if showAnswer {
                AdaptiveText(text: answerText)
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

    private struct AdaptiveText: View {
        let text: String

        var body: some View {
            Text(text)
                .font(.system(size: fontSize(for: text)))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .lineLimit(3)
        }

        private func fontSize(for text: String) -> CGFloat {
            switch text.count {
            case 0..<20: return 34
            case 20..<40: return 28
            default: return 24
            }
        }
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
