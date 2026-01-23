import Foundation

enum FileHelper {
    static func getFileType(ext: String, mimeType: String) -> FileType {
        let normalizedExt = ext.lowercased().replacingOccurrences(of: ".", with: "").trimmingCharacters(in: .whitespaces)
        return FileType(ext: normalizedExt, mimeType: mimeType)
    }

    static func buildFileName(fileName: String, extension ext: String) -> String {
        let cleanExt = ext.replacingOccurrences(of: ".", with: "").trimmingCharacters(in: .whitespaces)
        return cleanExt.isEmpty ? fileName : "\(fileName).\(cleanExt)"
    }

    static func writeFile(data: Data, to url: URL) throws {
        try writeFileWithProgress(data: data, to: url, onProgress: nil)
    }

    /// Writes data to file with progress reporting
    ///
    /// - Parameters:
    ///   - data: Data to write
    ///   - url: File URL to write to
    ///   - onProgress: Optional progress callback (0.0 to 1.0)
    static func writeFileWithProgress(
        data: Data,
        to url: URL,
        onProgress: ((Double) -> Void)?
    ) throws {
        // Create empty file first (FileHandle requires file to exist)
        FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil)

        if #available(iOS 13.4, *) {
            // iOS 13.4+ - Use modern write API with error handling
            let fileHandle = try FileHandle(forWritingTo: url)
            defer { try? fileHandle.close() }

            var offset = 0
            let chunkSize = Constants.chunkSize
            let totalBytes = data.count

            while offset < totalBytes {
                let length = min(chunkSize, totalBytes - offset)
                let chunk = data.subdata(in: offset..<(offset + length))
                try fileHandle.write(contentsOf: chunk)
                offset += length

                // Report progress
                if let onProgress = onProgress, totalBytes > 0 {
                    let progress = Double(offset) / Double(totalBytes)
                    onProgress(progress)
                }
            }
        } else {
            // iOS 13.0-13.3 fallback - Use legacy write API
            let fileHandle = try FileHandle(forWritingTo: url)
            defer { fileHandle.closeFile() }

            var offset = 0
            let chunkSize = Constants.chunkSize
            let totalBytes = data.count

            while offset < totalBytes {
                let length = min(chunkSize, totalBytes - offset)
                let chunk = data.subdata(in: offset..<(offset + length))
                fileHandle.write(chunk)
                offset += length

                // Report progress
                if let onProgress = onProgress, totalBytes > 0 {
                    let progress = Double(offset) / Double(totalBytes)
                    onProgress(progress)
                }
            }
        }
    }

    static func ensureDirectoryExists(at url: URL) throws {
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: url.path) {
            var isDirectory: ObjCBool = false
            fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)

            if !isDirectory.boolValue {
                throw FileSaverError.fileIO("Path exists but is not a directory: \(url.path)")
            }
        } else {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
    }
}
