import SwiftUI
import UniformTypeIdentifiers

struct TopicModeView: View {
    @EnvironmentObject private var vocabularyStore: VocabularyStore
    @ObservedObject var practiceStore: PracticeStore
    @EnvironmentObject private var topicProgressStore: TopicProgressStore
    @EnvironmentObject private var topicSessionStore: TopicSessionStore
    @EnvironmentObject private var autoSaveCoordinator: AutoSaveCoordinator

    @State private var showImporter = false
    @State private var isImporting = false
    @State private var activeAlert: ImportAlert?
    @State private var topicPendingDeletion: VocabularyTopic?
    @State private var stateAlert: StateAlert?

    private var topics: [VocabularyTopic] {
        vocabularyStore.topics
    }

    var body: some View {
        NavigationView {
            ZStack {
                Group {
                    if topics.isEmpty {
                        VStack(spacing: 12) {
                            Text("No topics found")
                                .font(.title3)
                            Text("Import vocab files or .zip archives to unlock topic practice.")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    } else {
                        List(topics) { topic in
                            NavigationLink(destination: TopicDetailView(topic: topic,
                                                                        practiceStore: practiceStore)) {
                                topicRowContent(for: topic)
                            }
                            .swipeActions(edge: .trailing) {
                                if topic.isDeletable {
                                    Button(role: .destructive) {
                                        topicPendingDeletion = topic
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                }

                if isImporting {
                    ProgressView("Importing…")
                        .progressViewStyle(.circular)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
                        .shadow(radius: 8)
                }
            }
            .navigationTitle("Topics")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button("Save state", action: saveAppState)
                        Button("Load state", action: loadAppState)
                        Toggle("Auto-save on change", isOn: $autoSaveCoordinator.isEnabled)
                    } label: {
                        Label("State", systemImage: "externaldrive")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showImporter = true }) {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                    .disabled(isImporting)
                }
            }
            .fileImporter(isPresented: $showImporter,
                          allowedContentTypes: [.commaSeparatedText, .zip],
                          allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    importFile(at: url)
                case .failure(let error):
                    if let nsError = error as NSError?, nsError.code == NSUserCancelledError {
                        return
                    }
                    activeAlert = .failure(error.localizedDescription)
                }
            }
            .alert(item: $activeAlert) { alert in
                switch alert {
                case .success(let message):
                    return Alert(title: Text("Success"),
                                 message: Text(message),
                                 dismissButton: .default(Text("OK")))
                case .failure(let message):
                    return Alert(title: Text("Something went wrong"),
                                 message: Text(message),
                                 dismissButton: .default(Text("OK")))
                }
            }
            .confirmationDialog("Delete Topic?",
                                isPresented: Binding(get: {
                                    topicPendingDeletion != nil
                                }, set: { newValue in
                                    if !newValue {
                                        topicPendingDeletion = nil
                                    }
                                }),
                                titleVisibility: .visible) {
                if let topic = topicPendingDeletion {
                    Button("Delete \(topic.displayName)", role: .destructive) {
                        delete(topic)
                    }
                }
                Button("Cancel", role: .cancel) { topicPendingDeletion = nil }
            } message: {
                if let topic = topicPendingDeletion {
                    Text("This removes \(topic.displayName) and clears any related practice data.")
                }
            }
            .alert(item: $stateAlert) { alert in
                Alert(title: Text(alert.title),
                      message: Text(alert.message),
                      dismissButton: .default(Text("OK")))
            }
        }
    }

    private func importFile(at url: URL) {
        isImporting = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try vocabularyStore.importTopics(from: url)
                let message: String
                if result.importedCount == 1, let name = result.importedFileNames.first {
                    message = "Imported \(friendlyName(for: name))."
                } else {
                    message = "Imported \(result.importedCount) files."
                }
                DispatchQueue.main.async {
                    isImporting = false
                    activeAlert = .success(message)
                }
            } catch {
                DispatchQueue.main.async {
                    isImporting = false
                    let message = (error as? TopicImportError)?.localizedDescription ?? error.localizedDescription
                    activeAlert = .failure(message)
                }
            }
        }
    }

    private func friendlyName(for fileName: String) -> String {
        fileName
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: ".csv", with: "", options: .caseInsensitive)
            .capitalized
    }

    @ViewBuilder
    private func topicRowContent(for topic: VocabularyTopic) -> some View {
        let state = topicProgressStore.state(for: topic, entries: topic.entries)
        let total = topic.entries.count
        let completed = min(state.completedCardIDs.count, total)
        VStack(alignment: .leading, spacing: 6) {
            Text(topic.displayName)
                .font(.headline)
            if total > 0 {
                ProgressView(value: Double(completed), total: Double(total))
                    .accentColor(completed >= total && total > 0 ? .green : .accentColor)
                HStack {
                    Text("\(completed)/\(total) cards")
                    Spacer()
                    Text("Finished \(state.completionCount) times")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            } else {
                Text("No cards in this topic yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func delete(_ topic: VocabularyTopic) {
        do {
            try vocabularyStore.deleteTopic(topic)
            practiceStore.remove(entries: topic.entries)
            topicProgressStore.clear(topic: topic)
            topicSessionStore.clear(for: topic.id)
            topicPendingDeletion = nil
            activeAlert = .success("\(topic.displayName) deleted.")
        } catch {
            topicPendingDeletion = nil
            let message = (error as? TopicImportError)?.localizedDescription ?? error.localizedDescription
            activeAlert = .failure(message)
        }
    }

    private func saveAppState() {
        do {
            _ = try AppStateSaver.save(practiceStore: practiceStore,
                                       topicProgressStore: topicProgressStore,
                                       topicSessionStore: topicSessionStore)
            stateAlert = .success("State saved to Files ▸ On My iPhone ▸ FlashCardsState.")
        } catch {
            stateAlert = .failure(error.localizedDescription)
        }
    }

    private func loadAppState() {
        do {
            let snapshot = try AppStateSaver.load()
            practiceStore.load(states: snapshot.practiceStates)
            topicProgressStore.load(states: snapshot.topicProgressStates)
            topicSessionStore.load(snapshots: snapshot.topicSessionSnapshots)
            stateAlert = .success("State loaded successfully.")
        } catch {
            stateAlert = .failure(error.localizedDescription)
        }
    }

    private enum ImportAlert: Identifiable {
        case success(String)
        case failure(String)

        var id: String {
            switch self {
            case .success(let message):
                return "success-\(message)"
            case .failure(let message):
                return "failure-\(message)"
            }
        }
    }

    private enum StateAlert: Identifiable {
        case success(String)
        case failure(String)

        var id: String { UUID().uuidString }
        var title: String {
            switch self {
            case .success:
                return "State Update"
            case .failure:
                return "State Error"
            }
        }
        var message: String {
            switch self {
            case .success(let message):
                return message
            case .failure(let message):
                return message
            }
        }
    }
}

private struct TopicDetailView: View {
    enum TopicMode: String, CaseIterable, Identifiable {
        case flashcards = "Flashcards"
        case multipleChoice = "Multiple Choice"

        var id: String { rawValue }
    }

    let topic: VocabularyTopic
    @ObservedObject var practiceStore: PracticeStore
    @EnvironmentObject private var topicProgressStore: TopicProgressStore
    @EnvironmentObject private var topicSessionStore: TopicSessionStore

    @State private var selectedMode: TopicMode = .flashcards
    @State private var showCompletionEditor = false
    @State private var manualCompletionCount = ""

    var body: some View {
        VStack(spacing: 16) {
            TopicProgressSummary(topic: topic,
                                 state: topicProgressStore.state(for: topic, entries: topic.entries),
                                 resetAction: restartIfNeeded,
                                 editAction: { presentCompletionEditor() })
            Picker("Mode", selection: $selectedMode) {
                ForEach(TopicMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            switch selectedMode {
            case .flashcards:
                FlashcardSessionView(entries: topic.entries,
                                     practiceStore: practiceStore,
                                     onCardComplete: { entry in
                    topicProgressStore.markCompleted(entry, in: topic)
                },
                                     sessionKey: topic.id,
                                     sessionStore: topicSessionStore)
            case .multipleChoice:
                MultipleChoiceSessionView(entries: topic.entries,
                                          practiceStore: practiceStore,
                                          allowsPoolSelection: false,
                                          onQuestionFinished: { entry in
                    topicProgressStore.markCompleted(entry, in: topic)
                })
            }

            Spacer(minLength: 0)
        }
        .padding()
        .navigationTitle(topic.displayName)
        .sheet(isPresented: $showCompletionEditor) {
            ManualCompletionEditor(isPresented: $showCompletionEditor,
                                   initialValue: topicProgressStore.state(for: topic, entries: topic.entries).completionCount,
                                   onSave: { newValue in
                topicProgressStore.setCompletionCount(newValue, for: topic)
            })
        }
    }

    private func restartIfNeeded() {
        let state = topicProgressStore.state(for: topic, entries: topic.entries)
        guard topic.entries.count > 0,
              state.completedCardIDs.count >= topic.entries.count else { return }
        topicProgressStore.reset(topic: topic, incrementCompletion: true)
        topicSessionStore.clear(for: topic.id)
    }

    private func presentCompletionEditor() {
        manualCompletionCount = "\(topicProgressStore.state(for: topic, entries: topic.entries).completionCount)"
        showCompletionEditor = true
    }
}

private struct TopicProgressSummary: View {
    let topic: VocabularyTopic
    let state: TopicProgressState
    let resetAction: () -> Void
    let editAction: () -> Void

    private var total: Int { topic.entries.count }
    private var completed: Int { min(state.completedCardIDs.count, total) }
    private var remaining: Int { max(total - completed, 0) }
    private var isComplete: Bool {
        total > 0 && completed >= total
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if total > 0 {
                ProgressView(value: Double(completed), total: Double(total))
                    .accentColor(isComplete ? .green : .accentColor)
                HStack {
                    Text("\(completed)/\(total) cards")
                    Spacer()
                    Text("\(remaining) left")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            } else {
                Text("No cards in this topic yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("Completed \(state.completionCount) time(s)")
                .font(.caption)
                .foregroundColor(.secondary)
                .contextMenu {
                    Button("Edit completion count") {
                        editAction()
                    }
                }

            if isComplete {
                Button("Restart topic") {
                    resetAction()
                }
                .buttonStyle(.borderedProminent)
                .contextMenu {
                    Button("Edit completion count") {
                        editAction()
                    }
                }
            } else {
                Button("Edit completion count") {
                    editAction()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }
}

private struct ManualCompletionEditor: View {
    @Binding var isPresented: Bool
    @State private var value: String
    let onSave: (Int) -> Void

    init(isPresented: Binding<Bool>, initialValue: Int, onSave: @escaping (Int) -> Void) {
        self._isPresented = isPresented
        self._value = State(initialValue: "\(initialValue)")
        self.onSave = onSave
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Completion Count")) {
                    TextField("Times completed", text: $value)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Edit Progress")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let newValue = Int(value) ?? 0
                        onSave(max(0, newValue))
                        isPresented = false
                    }
                }
            }
        }
    }
}
