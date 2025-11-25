import Foundation

enum VocabularyLoader {
    enum LoaderError: LocalizedError {
        case fileMissing
        case parsingFailed(fileName: String)

        var errorDescription: String? {
            switch self {
            case .fileMissing:
                return "No CSV files were found in the bundled csv_files folder or in your imported topics."
            case .parsingFailed(let fileName):
                return "Unable to parse \(fileName). Please make sure the CSV is UTF-8 encoded and has at least three columns."
            }
        }
    }

    static func loadTopics(userDirectory: URL? = nil) throws -> [VocabularyTopic] {
        let bundleURLs = csvFiles(inBundle: Bundle.main)
        let userURLs = userDirectory.map { csvFiles(inDirectory: $0) } ?? []
        guard !(bundleURLs.isEmpty && userURLs.isEmpty) else {
            throw LoaderError.fileMissing
        }

        var topics: [VocabularyTopic] = []
        for url in bundleURLs {
            let fileName = url.deletingPathExtension().lastPathComponent
            do {
                let entries = try parseEntries(from: url)
                guard !entries.isEmpty else { continue }
                topics.append(VocabularyTopic(name: fileName, entries: entries, sourceURL: nil))
            } catch {
                throw LoaderError.parsingFailed(fileName: fileName)
            }
        }

        for url in userURLs {
            let fileName = url.deletingPathExtension().lastPathComponent
            do {
                let entries = try parseEntries(from: url)
                guard !entries.isEmpty else { continue }
                topics.append(VocabularyTopic(name: fileName, entries: entries, sourceURL: url))
            } catch {
                throw LoaderError.parsingFailed(fileName: fileName)
            }
        }

        return topics.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func parseEntries(from url: URL) throws -> [VocabularyEntry] {
        let contents = try String(contentsOf: url, encoding: .utf8)
        let rows = contents
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard rows.count > 1 else { return [] }

        var entries: [VocabularyEntry] = []
        for row in rows.dropFirst() {
            let columns = row.splitCSV()
            guard columns.count >= 3 else { continue }
            let german = columns[0]
            let plural = columns[1].isEmpty ? nil : columns[1]
            let english = columns[2]
            entries.append(VocabularyEntry(german: german, plural: plural, english: english))
        }
        return entries
    }

    private static func csvFiles(inBundle bundle: Bundle) -> [URL] {
        var urls: [URL] = []
        if let folderURLs = bundle.urls(forResourcesWithExtension: "csv", subdirectory: "csv_files") {
            urls.append(contentsOf: folderURLs)
        }
        if let rootURLs = bundle.urls(forResourcesWithExtension: "csv", subdirectory: nil) {
            urls.append(contentsOf: rootURLs.filter { !$0.path.contains("/csv_files/") })
        }
        return urls
    }

    private static func csvFiles(inDirectory directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }
        var urls: [URL] = []
        for case let fileURL as URL in enumerator where fileURL.pathExtension.lowercased() == "csv" {
            urls.append(fileURL)
        }
        return urls
    }
}

private extension String {
    func splitCSV() -> [String] {
        var results: [String] = []
        var value = ""
        var insideQuotes = false
        for character in self {
            if character == "\"" {
                insideQuotes.toggle()
                continue
            }
            if character == "," && !insideQuotes {
                results.append(value)
                value.removeAll(keepingCapacity: true)
            } else {
                value.append(character)
            }
        }
        results.append(value)
        return results.map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
