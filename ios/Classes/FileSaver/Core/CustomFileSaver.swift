import Foundation

class CustomFileSaver: BaseFileSaver {

    func saveBytes(
        fileData: Data,
        fileType: FileType,
        baseFileName: String,
        saveLocation: SaveLocation,
        subDir: String?,
        conflictResolution: ConflictResolution,
        onProgress: ((Double) -> Void)?
    ) throws -> SaveResult {
        try validateFileData(fileData)

        // Custom files always use Documents directory regardless of saveLocation
        var targetDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        if let subDir = subDir {
            targetDir = targetDir.appendingPathComponent(subDir)
        }

        try FileHelper.ensureDirectoryExists(at: targetDir)

        let fileName = buildFileName(base: baseFileName, extension: fileType.ext)
        let finalURL = try FileManagerConflictResolver.resolveConflict(
            directory: targetDir,
            fileName: fileName,
            conflictResolution: conflictResolution
        )

        try FileHelper.writeFileWithProgress(data: fileData, to: finalURL, onProgress: onProgress)

        return .success(filePath: finalURL.path, fileUri: finalURL.absoluteString)
    }
}
