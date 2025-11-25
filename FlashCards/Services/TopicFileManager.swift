import Foundation
import Compression

struct TopicImportResult {
    let importedFileNames: [String]

    var importedCount: Int {
        importedFileNames.count
    }
}

enum TopicImportError: LocalizedError {
    case unsupportedType
    case noCSVInArchive
    case copyFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedType:
            return "Please choose a .csv file or a .zip archive that contains CSV files."
        case .noCSVInArchive:
            return "The selected archive does not contain any CSV files."
        case .copyFailed:
            return "Unable to import the selected file. Please try again."
        }
    }
}

final class TopicFileManager {
    private let fileManager: FileManager
    let topicsDirectory: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let directory = documents.appendingPathComponent("ImportedTopics", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        self.topicsDirectory = directory
    }

    func importTopics(from sourceURL: URL) throws -> TopicImportResult {
        let needsAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if needsAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileExtension = sourceURL.pathExtension.lowercased()
        switch fileExtension {
        case "csv":
            return try importCSV(from: sourceURL)
        case "zip":
            return try importZIP(from: sourceURL)
        default:
            throw TopicImportError.unsupportedType
        }
    }

    private func importCSV(from url: URL) throws -> TopicImportResult {
        let destination = uniqueDestinationURL(for: url.lastPathComponent)
        do {
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: url, to: destination)
            return TopicImportResult(importedFileNames: [destination.lastPathComponent])
        } catch {
            throw TopicImportError.copyFailed
        }
    }

    private func importZIP(from url: URL) throws -> TopicImportResult {
        let tempDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
            defer { try? fileManager.removeItem(at: tempDirectory) }
            try unzipArchive(at: url, to: tempDirectory)
            var imported: [String] = []
            if let enumerator = fileManager.enumerator(at: tempDirectory, includingPropertiesForKeys: nil) {
                for case let fileURL as URL in enumerator where fileURL.pathExtension.lowercased() == "csv" {
                    let destination = uniqueDestinationURL(for: fileURL.lastPathComponent)
                    do {
                        if fileManager.fileExists(atPath: destination.path) {
                            try fileManager.removeItem(at: destination)
                        }
                        try fileManager.copyItem(at: fileURL, to: destination)
                        imported.append(destination.lastPathComponent)
                    } catch {
                        throw TopicImportError.copyFailed
                    }
                }
            }
            guard !imported.isEmpty else { throw TopicImportError.noCSVInArchive }
            return TopicImportResult(importedFileNames: imported)
        } catch let error as TopicImportError {
            throw error
        } catch {
            throw TopicImportError.copyFailed
        }
    }

    private func uniqueDestinationURL(for fileName: String) -> URL {
        let sanitized = sanitize(fileName: fileName)
        let baseURL = URL(fileURLWithPath: sanitized)
        let baseName = baseURL.deletingPathExtension().lastPathComponent
        let ext = baseURL.pathExtension.isEmpty ? "csv" : baseURL.pathExtension
        var candidate = sanitized
        var counter = 1
        var destination = topicsDirectory.appendingPathComponent(candidate)
        while fileManager.fileExists(atPath: destination.path) {
            candidate = "\(baseName)_\(counter).\(ext)"
            destination = topicsDirectory.appendingPathComponent(candidate)
            counter += 1
        }
        return destination
    }

    private func sanitize(fileName: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let base = fileName.replacingOccurrences(of: " ", with: "_")
        var sanitized = base.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }.reduce("") { $0 + String($1) }
        if sanitized.isEmpty {
            sanitized = UUID().uuidString
        }
        if !sanitized.lowercased().hasSuffix(".csv") {
            sanitized.append(".csv")
        }
        return sanitized
    }

    private func unzipArchive(at sourceURL: URL, to destinationURL: URL) throws {
        let archiveData = try Data(contentsOf: sourceURL)
        guard let centralDirectoryOffset = findCentralDirectoryOffset(in: archiveData) else {
            throw TopicImportError.copyFailed
        }

        var index = centralDirectoryOffset
        let centralDirectorySignature: UInt32 = 0x02014B50
        let localHeaderSignature: UInt32 = 0x04034B50

        while index + 46 <= archiveData.count {
            let signature = archiveData.readUInt32LE(at: index)
            if signature != centralDirectorySignature {
                break
            }

            let compressionMethod = archiveData.readUInt16LE(at: index + 10)
            let compressedSize = Int(archiveData.readUInt32LE(at: index + 20))
            let uncompressedSize = Int(archiveData.readUInt32LE(at: index + 24))
            let fileNameLength = Int(archiveData.readUInt16LE(at: index + 28))
            let extraFieldLength = Int(archiveData.readUInt16LE(at: index + 30))
            let commentLength = Int(archiveData.readUInt16LE(at: index + 32))
            let localHeaderOffset = Int(archiveData.readUInt32LE(at: index + 42))

            let nameStart = index + 46
            let nameEnd = nameStart + fileNameLength
            guard nameEnd <= archiveData.count else { throw TopicImportError.copyFailed }
            let nameData = archiveData.subdata(in: nameStart..<nameEnd)
            let fileName = String(data: nameData, encoding: .utf8) ?? UUID().uuidString

            guard archiveData.readUInt32LE(at: localHeaderOffset) == localHeaderSignature else {
                throw TopicImportError.copyFailed
            }
            let localNameLength = Int(archiveData.readUInt16LE(at: localHeaderOffset + 26))
            let localExtraLength = Int(archiveData.readUInt16LE(at: localHeaderOffset + 28))
            let dataStart = localHeaderOffset + 30 + localNameLength + localExtraLength
            let dataEnd = dataStart + compressedSize
            guard dataEnd <= archiveData.count else { throw TopicImportError.copyFailed }

            let entryURL = destinationURL.appendingPathComponent(fileName)
            try fileManager.createDirectory(at: entryURL.deletingLastPathComponent(), withIntermediateDirectories: true)

            if fileName.hasSuffix("/") {
                try fileManager.createDirectory(at: entryURL, withIntermediateDirectories: true)
            } else {
                let entryData = archiveData.subdata(in: dataStart..<dataEnd)
                let outputData: Data
                switch compressionMethod {
                case 0:
                    outputData = entryData
                case 8:
                    outputData = try inflate(data: entryData, expectedSize: uncompressedSize)
                default:
                    throw TopicImportError.copyFailed
                }
                try outputData.write(to: entryURL)
            }

            index = nameEnd + extraFieldLength + commentLength
        }
    }

    private func inflate(data: Data, expectedSize: Int) throws -> Data {
        let dummySrc = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
        let dummyDst = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
        defer {
            dummySrc.deallocate()
            dummyDst.deallocate()
        }
        var stream = compression_stream(dst_ptr: dummyDst,
                                        dst_size: 0,
                                        src_ptr: UnsafePointer(dummySrc),
                                        src_size: 0,
                                        state: nil)
        let status = compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB)
        guard status != COMPRESSION_STATUS_ERROR else {
            throw TopicImportError.copyFailed
        }
        defer { compression_stream_destroy(&stream) }

        let bufferCapacity = max(expectedSize, 64 * 1024)
        var output = Data()
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferCapacity)
        defer { destinationBuffer.deallocate() }

        var finalStatus = COMPRESSION_STATUS_OK
        data.withUnsafeBytes { srcBuffer in
            guard let baseAddress = srcBuffer.bindMemory(to: UInt8.self).baseAddress else { return }
            stream.src_ptr = baseAddress
            stream.src_size = data.count

            repeat {
                stream.dst_ptr = destinationBuffer
                stream.dst_size = bufferCapacity
                let flags: Int32 = stream.src_size == 0 ? Int32(COMPRESSION_STREAM_FINALIZE.rawValue) : 0
                finalStatus = compression_stream_process(&stream, flags)
                let produced = bufferCapacity - stream.dst_size
                if produced > 0 {
                    output.append(destinationBuffer, count: produced)
                }
            } while finalStatus == COMPRESSION_STATUS_OK
        }

        guard finalStatus == COMPRESSION_STATUS_END else {
            throw TopicImportError.copyFailed
        }
        return output
    }

    private func findCentralDirectoryOffset(in data: Data) -> Int? {
        let eocdSignature: UInt32 = 0x06054B50
        let minEOCDSize = 22
        guard data.count >= minEOCDSize else { return nil }
        let searchStart = max(0, data.count - 65_535 - minEOCDSize)
        var index = data.count - minEOCDSize
        while index >= searchStart {
            if data.readUInt32LE(at: index) == eocdSignature {
                return Int(data.readUInt32LE(at: index + 16))
            }
            index -= 1
        }
        return nil
    }
}

private extension Data {
    func readUInt16LE(at offset: Int) -> UInt16 {
        precondition(offset + 2 <= count)
        let byte0 = UInt16(self[offset])
        let byte1 = UInt16(self[offset + 1]) << 8
        return byte0 | byte1
    }

    func readUInt32LE(at offset: Int) -> UInt32 {
        precondition(offset + 4 <= count)
        var value: UInt32 = 0
        for i in 0..<4 {
            value |= UInt32(self[offset + i]) << (8 * UInt32(i))
        }
        return value
    }
}
