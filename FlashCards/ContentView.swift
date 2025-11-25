import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var vocabularyStore: VocabularyStore
    @ObservedObject var practiceStore: PracticeStore

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
                FlashcardDeckView(entries: vocabularyStore.entries, practiceStore: practiceStore)
                    .tabItem {
                        Label("Flashcards", systemImage: "rectangle.on.rectangle")
                    }

                TopicModeView(practiceStore: practiceStore)
                    .tabItem {
                        Label("Topics", systemImage: "folder")
                    }

                PracticeDeckView(entries: vocabularyStore.entries, practiceStore: practiceStore)
                    .tabItem {
                        Label("Practice", systemImage: "repeat")
                    }
            }
        }
    }
}
