# FlashCards (iOS)

German ↔ English flashcard trainer built with SwiftUI. The app loads vocabulary from CSV files, lets you flip flashcards, mark difficult cards for focused practice, and run multiple-choice drills. Each CSV file becomes its own “topic” so you can study one group of words at a time or combine everything.

## Requirements

- macOS with **Xcode 15** (or newer) to build and run the iOS app.
- iOS 16+ simulator or device.

## Project Structure

- `FlashCards/` – SwiftUI source, Xcode target assets, and bundled resources.
- `csv_files/` – working folder for your CSVs outside the Xcode bundle (kept out of git).
- `FlashCards/Resources/csv_files/` – CSVs that ship inside the app bundle. Every `.csv` file here is parsed into a topic at launch.

## CSV Format

The loader expects a header row followed by vocabulary rows:

```
German,Plural,English
der Staat,die Staaten,state
die Grenze,die Grenzen,state frontier / border
```

- Column 1: German word (include articles).
- Column 2: Plural form (optional; leave empty to skip).
- Column 3: English translation.

## Adding Topics / CSV Files (Manually)

1. Drop or generate your CSV file in the root `csv_files/` folder for local editing.
2. Copy that file into `FlashCards/Resources/csv_files/` so it’s bundled with the app:
   ```bash
   cp csv_files/new_topic.csv FlashCards/Resources/csv_files/
   ```
3. Rebuild the app in Xcode. The filename (without extension) becomes the topic name in the Topics tab (underscores are converted to spaces and capitalized).

You can bundle multiple CSVs; each appears as its own topic while the main Flashcards tab still includes every card.

## Importing Topics Inside the App

Instead of copying files manually, open the **Topics** tab in the app and tap the import button (arrow icon). You can pick:

- A single `.csv` file.
- A `.zip` archive containing one or more CSV files (nested folders are supported).

Imported files are copied into the app’s Documents directory and included on the next reload automatically. ZIP imports support the common “deflate” compression produced by the macOS/iOS Files apps; password-protected archives or uncommon compression methods are ignored.

## Running the App

1. Open `FlashCards.xcodeproj` in Xcode.
2. Select the `FlashCards` scheme and an iPhone simulator/device.
3. Build & Run (`Cmd+R`).

## Using the App

- **Flashcards tab** – Flip between German→English or English→German, tap “I got it wrong” to push cards into the practice queue.
- **Topics tab** – Choose a CSV-derived topic and study it via flashcards or multiple choice.
- **Practice tab** – Cycles only the cards you flagged as wrong; they stay until answered correctly 5 times.
- **Multiple Choice tab** – Drill either the whole deck or only the practice subset; wrong answers re-queue the card automatically.

Data about wrong/right streaks is stored locally in `UserDefaults`, so your progress persists between launches.
