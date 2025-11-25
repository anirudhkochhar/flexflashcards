import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var vocabularyStore: VocabularyStore
    @ObservedObject var flashcardPractice: PracticeStore
    @ObservedObject var multipleChoicePractice: PracticeStore

    var body: some View {
        if let error = vocabularyStore.loadError {
            VStack(spacing: 12) {
                Text("Something went wrong")
                    .font(.title2)
                Text(error.localizedDescription)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                Button("Retry") {
                    vocabularyStore.loadVocabulary()
                }
            }
            .padding()
        } else {
            TabView {
                FlashcardDeckView(entries: vocabularyStore.entries, practiceStore: flashcardPractice)
                    .tabItem {
                        Label("Flashcards", systemImage: "rectangle.on.rectangle")
                    }

                TopicModeView(flashcardPractice: flashcardPractice,
                              multipleChoicePractice: multipleChoicePractice)
                    .tabItem {
                        Label("Topics", systemImage: "folder")
                    }

                PracticeDeckView(entries: vocabularyStore.entries, practiceStore: flashcardPractice)
                    .tabItem {
                        Label("Practice", systemImage: "repeat")
                    }

                MultipleChoiceModeView(entries: vocabularyStore.entries, practiceStore: multipleChoicePractice)
                    .tabItem {
                        Label("Multiple Choice", systemImage: "list.bullet.rectangle")
                    }
            }
        }
    }
}
