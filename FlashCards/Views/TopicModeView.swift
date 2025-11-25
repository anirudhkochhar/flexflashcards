import SwiftUI
import UniformTypeIdentifiers

struct TopicModeView: View {
    @EnvironmentObject private var vocabularyStore: VocabularyStore
    @ObservedObject var practiceStore: PracticeStore

    @State private var showImporter = false
    @State private var isImporting = false
    @State private var activeAlert: ImportAlert?

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
                            Text("Import CSV files or .zip archives to unlock topic practice.")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    } else {
                        List(topics) { topic in
                            NavigationLink(destination: TopicDetailView(topic: topic,
                                                                        practiceStore: practiceStore)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(topic.displayName)
                                        .font(.headline)
                                    Text("\(topic.entries.count) cards")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
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
                    return Alert(title: Text("Import Complete"),
                                 message: Text(message),
                                 dismissButton: .default(Text("OK")))
                case .failure(let message):
                    return Alert(title: Text("Import Failed"),
                                 message: Text(message),
                                 dismissButton: .default(Text("OK")))
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

    @State private var selectedMode: TopicMode = .flashcards

    var body: some View {
        VStack(spacing: 16) {
            Picker("Mode", selection: $selectedMode) {
                ForEach(TopicMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            switch selectedMode {
            case .flashcards:
                FlashcardSessionView(entries: topic.entries, practiceStore: practiceStore)
            case .multipleChoice:
                MultipleChoiceSessionView(entries: topic.entries,
                                          practiceStore: practiceStore,
                                          allowsPoolSelection: false)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .navigationTitle(topic.displayName)
    }
}
