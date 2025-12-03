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
    var sessionKey: String? = nil
    var sessionStore: TopicSessionStore? = nil

    @State private var showAnswer = false
    @State private var orientation: CardOrientation = .germanToEnglish
    @State private var order: [Int] = []
    @State private var position: Int = 0
    @State private var entriesSignature: String = ""

    var body: some View {
        VStack(spacing: 16) {
            if let entry = currentEntry {
                FlashcardView(entry: entry,
                              orientation: orientation,
                              showAnswer: showAnswer,
                              practiceStore: practiceStore)
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
        .onAppear { loadOrSyncOrder(force: true) }
        .onChange(of: entriesSignatureValue) { _ in loadOrSyncOrder(force: true) }
    }

    private var entriesSignatureValue: String {
        entries.map(\.id).joined(separator: "|")
    }

    private var currentEntry: VocabularyEntry? {
        guard !order.isEmpty else { return nil }
        let idx = order[position % order.count]
        guard entries.indices.contains(idx) else { return nil }
        return entries[idx]
    }

    private var shouldPersistOrder: Bool {
        sessionKey != nil && sessionStore != nil
    }

    private func loadOrSyncOrder(force: Bool) {
        guard !entries.isEmpty else {
            order = []
            position = 0
            showAnswer = false
            entriesSignature = ""
            saveSnapshot()
            return
        }
        let newSignature = entriesSignatureValue
        if force || newSignature != entriesSignature || order.isEmpty {
            entriesSignature = newSignature
            if shouldPersistOrder,
               let key = sessionKey,
               let store = sessionStore,
               let snapshot = store.snapshot(for: key),
               applySnapshot(snapshot) {
                return
            }
            order = entries.indices.shuffled()
            position = 0
            showAnswer = false
            saveSnapshot()
        } else if position >= order.count {
            position = 0
            showAnswer = false
        }
    }

    private func applySnapshot(_ snapshot: FlashcardRunSnapshot?) -> Bool {
        guard let snapshot = snapshot else { return false }
        let idToIndex = Dictionary(uniqueKeysWithValues: entries.enumerated().map { ($0.element.id, $0.offset) })
        let mapped = snapshot.orderIDs.compactMap { idToIndex[$0] }
        guard !mapped.isEmpty else { return false }
        order = mapped
        position = min(max(0, snapshot.position), max(0, order.count - 1))
        showAnswer = false
        return true
    }

    private func nextCard() {
        guard !order.isEmpty else { return }
        position += 1
        if position >= order.count {
            if shouldPersistOrder {
                position = 0
            } else {
                order = entries.indices.shuffled()
                position = 0
            }
        }
        showAnswer = false
        saveSnapshot()
    }

    private func previousCard() {
        guard !order.isEmpty else { return }
        position = (position - 1 + order.count) % order.count
        showAnswer = false
        saveSnapshot()
    }

    private func addToPractice(_ entry: VocabularyEntry) {
        practiceStore.markWrong(for: entry)
    }

    private func primaryAction(for entry: VocabularyEntry) {
        if showAnswer {
            onCardComplete?(entry)
            nextCard()
        } else {
            withAnimation { showAnswer = true }
        }
    }

    private func saveSnapshot() {
        guard shouldPersistOrder,
              let key = sessionKey,
              let store = sessionStore,
              !order.isEmpty else { return }
        let ids = order.compactMap { entries.indices.contains($0) ? entries[$0].id : nil }
        let snapshot = FlashcardRunSnapshot(orderIDs: ids, position: position)
        store.save(snapshot: snapshot, for: key)
    }
}

struct FlashcardView: View {
    let entry: VocabularyEntry
    let orientation: CardOrientation
    let showAnswer: Bool
    var practiceStore: PracticeStore?

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
            if showAnswer, let plural = entry.plural {
                Text("Plural: \(plural)")
                    .foregroundColor(.secondary)
            }
            if showAnswer, let practiceStore = practiceStore, practiceStore.isActive(entry) {
                Text(streakText(for: entry, in: practiceStore))
                    .font(.caption)
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

    private func streakText(for entry: VocabularyEntry, in store: PracticeStore) -> String {
        let state = store.states[entry.id] ?? .empty
        return "Practice streak: \(state.correctStreak)/\(store.goalStreak)"
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
