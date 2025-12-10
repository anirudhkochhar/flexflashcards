import SwiftUI
import UniformTypeIdentifiers

private enum DocumentPickerPurpose {
    case importTopics
    case manualSave
    case manualLoad
    case autoSaveFolder

    var contentTypes: [UTType] {
        switch self {
        case .importTopics:
            return [.commaSeparatedText, .zip]
        case .manualSave:
            return [.folder]
        case .manualLoad:
            return [.folder, .json]
        case .autoSaveFolder:
            return [.folder]
        }
    }
}

private enum TopicStateAlert: Identifiable {
    case success(String)
    case failure(String)

    var id: String {
        switch self {
        case .success(let message):
            return "state-success-\(message)"
        case .failure(let message):
            return "state-failure-\(message)"
        }
    }

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

struct TopicModeView: View {
    @EnvironmentObject private var vocabularyStore: VocabularyStore
    @ObservedObject var practiceStore: PracticeStore
    @EnvironmentObject private var topicProgressStore: TopicProgressStore
    @EnvironmentObject private var topicSessionStore: TopicSessionStore
    @EnvironmentObject private var statePersistenceCoordinator: StatePersistenceCoordinator

    @State private var isImporting = false
    @State private var activeAlert: ImportAlert?
    @State private var topicPendingDeletion: VocabularyTopic?
    @State private var stateAlert: TopicStateAlert?
    @State private var documentPickerPurpose: DocumentPickerPurpose?
    @State private var documentPickerTypes: [UTType] = []
    @State private var showDocumentPicker = false

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
                        Button("Save state…") { presentDocumentPicker(for: .manualSave) }
                        Button("Load state…") { presentDocumentPicker(for: .manualLoad) }
                        Divider()
                        if let folderName = statePersistenceCoordinator.autoSaveFolderName {
                            Button("Change auto-save folder…") {
                                presentDocumentPicker(for: .autoSaveFolder)
                            }
                            Button("Stop auto-save", role: .destructive) {
                                statePersistenceCoordinator.clearAutoSaveFolder()
                                stateAlert = .success("Auto-save disabled.")
                            }
                            Text("Saving to \(folderName)")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        } else {
                            Button("Set auto-save folder…") {
                                presentDocumentPicker(for: .autoSaveFolder)
                            }
                            Text("Auto-save off")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    } label: {
                        Label("State", systemImage: "externaldrive")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { presentDocumentPicker(for: .importTopics) }) {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                    .disabled(isImporting)
                }
            }
            .fileImporter(isPresented: $showDocumentPicker,
                          allowedContentTypes: documentPickerTypes,
                          allowsMultipleSelection: false) { result in
                guard let purpose = documentPickerPurpose else { return }
                documentPickerPurpose = nil
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    handleDocument(url: url, purpose: purpose)
                case .failure(let error):
                    if let nsError = error as NSError?, nsError.code == NSUserCancelledError {
                        return
                    }
                    handleDocumentFailure(error, purpose: purpose)
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
            .alert(item: $stateAlert) { alert in
                Alert(title: Text(alert.title),
                      message: Text(alert.message),
                      dismissButton: .default(Text("OK")))
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

    private func presentDocumentPicker(for purpose: DocumentPickerPurpose) {
        documentPickerPurpose = purpose
        documentPickerTypes = purpose.contentTypes
        showDocumentPicker = true
    }

    private func handleDocument(url: URL, purpose: DocumentPickerPurpose) {
        switch purpose {
        case .importTopics:
            importFile(at: url)
        case .manualSave:
            saveStateManually(to: url)
        case .manualLoad:
            loadStateManually(from: url)
        case .autoSaveFolder:
            configureAutoSaveFolder(with: url)
        }
    }

    private func handleDocumentFailure(_ error: Error, purpose: DocumentPickerPurpose) {
        switch purpose {
        case .importTopics:
            activeAlert = .failure(error.localizedDescription)
        case .manualSave, .manualLoad, .autoSaveFolder:
            stateAlert = .failure(error.localizedDescription)
        }
    }

    private func saveStateManually(to folderURL: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            let needsAccess = folderURL.startAccessingSecurityScopedResource()
            defer {
                if needsAccess {
                    folderURL.stopAccessingSecurityScopedResource()
                }
            }
            do {
                let fileURL = try statePersistenceCoordinator.manualSave(to: folderURL)
                let name = friendlyName(for: fileURL.deletingLastPathComponent())
                DispatchQueue.main.async {
                    stateAlert = .success("State saved to \(name).")
                }
            } catch {
                DispatchQueue.main.async {
                    stateAlert = .failure(error.localizedDescription)
                }
            }
        }
    }

    private func loadStateManually(from url: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            let needsAccess = url.startAccessingSecurityScopedResource()
            defer {
                if needsAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            do {
                let snapshot = try statePersistenceCoordinator.manualLoad(from: url)
                let name = friendlyName(for: url)
                DispatchQueue.main.async {
                    do {
                        try applySnapshot(snapshot)
                        stateAlert = .success("State loaded from \(name).")
                    } catch {
                        stateAlert = .failure(error.localizedDescription)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    stateAlert = .failure(error.localizedDescription)
                }
            }
        }
    }

    private func configureAutoSaveFolder(with folderURL: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            let needsAccess = folderURL.startAccessingSecurityScopedResource()
            defer {
                if needsAccess {
                    folderURL.stopAccessingSecurityScopedResource()
                }
            }
            do {
                try statePersistenceCoordinator.setAutoSaveFolder(folderURL)
                let name = friendlyName(for: folderURL)
                DispatchQueue.main.async {
                    stateAlert = .success("Auto-save enabled for \(name).")
                }
            } catch {
                DispatchQueue.main.async {
                    stateAlert = .failure(error.localizedDescription)
                }
            }
        }
    }

    private func applySnapshot(_ snapshot: AppStateSnapshot) throws {
        if !snapshot.userTopics.isEmpty {
            try vocabularyStore.restoreUserTopics(from: snapshot.userTopics)
        } else {
            vocabularyStore.loadVocabulary()
        }

        let entryKeyBySavedID = Dictionary(uniqueKeysWithValues: snapshot.entrySignatures.map { ($0.entryID, $0.key) })
        let practiceStatesByKey: [String: PracticeCardState] = snapshot.entrySignatures.reduce(into: [:]) { result, signature in
            if let state = snapshot.practiceStates[signature.entryID] {
                result[signature.key] = state
            }
        }

        var newPracticeStates: [String: PracticeCardState] = [:]
        var entryIDByKey: [String: String] = [:]
        for topic in vocabularyStore.topics {
            let isUser = topic.sourceURL != nil
            for entry in topic.entries {
                let key = EntrySignatureSnapshot.makeKey(topicName: topic.name,
                                                         isUserTopic: isUser,
                                                         german: entry.german,
                                                         english: entry.english)
                entryIDByKey[key] = entry.id
                if let state = practiceStatesByKey[key] {
                    newPracticeStates[entry.id] = state
                }
            }
        }
        practiceStore.load(states: newPracticeStates)

        let topicSignaturesByID = Dictionary(uniqueKeysWithValues: snapshot.topicSignatures.map { ($0.topicID, $0.key) })
        var savedTopicStatesByKey: [String: TopicProgressState] = [:]
        for (topicID, state) in snapshot.topicProgressStates {
            guard let key = topicSignaturesByID[topicID] else { continue }
            savedTopicStatesByKey[key] = state
        }

        var newTopicStates: [String: TopicProgressState] = [:]
        for topic in vocabularyStore.topics {
            let key = TopicSignatureSnapshot.makeKey(name: topic.name,
                                                     isUserTopic: topic.sourceURL != nil)
            guard var savedState = savedTopicStatesByKey[key] else { continue }
            let mappedCompleted: Set<String> = Set(savedState.completedCardIDs.compactMap { oldID in
                guard let entryKey = entryKeyBySavedID[oldID] else { return nil }
                return entryIDByKey[entryKey]
            })
            savedState.completedCardIDs = mappedCompleted
            newTopicStates[topic.id] = savedState
        }
        topicProgressStore.load(states: newTopicStates)
    }

    private func friendlyName(for url: URL) -> String {
        let isDirectory: Bool
        if let value = try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory {
            isDirectory = value ?? url.hasDirectoryPath
        } else {
            isDirectory = url.hasDirectoryPath
        }
        if isDirectory {
            let name = url.lastPathComponent
            return name.isEmpty ? url.path : name
        }
        let name = url.lastPathComponent
        return name.isEmpty ? url.path : name
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
