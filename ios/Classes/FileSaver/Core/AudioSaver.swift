import Foundation

class AudioSaver: BaseFileSaver {

    func saveBytes(
        fileData: Data,
        fileType: FileType,
        baseFileName: String,
        saveLocation: SaveLocation,
        subDir: String?,
        conflictResolution: ConflictResolution,
        onProgress: ((Double) -> Void)?,
        onSuccess: (String) -> Void,
        cancellationToken: CancellationToken?
    ) throws {
        try FormatValidator.validateAudioFormat(fileType)
        try validateFileData(fileData)

        // Audio files always use Documents directory regardless of saveLocation
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

        do {
            try FileHelper.writeFileWithProgress(
                data: fileData,
                to: finalURL,
                onProgress: onProgress,
                cancellationToken: cancellationToken
            )
        } catch FileSaverError.cancelled {
            // Cleanup partial file on cancellation
            try? FileManager.default.removeItem(at: finalURL)
            throw FileSaverError.cancelled
        }

        onSuccess(finalURL.absoluteString)
    }

    func saveFile(
        filePath: String,
        fileType: FileType,
        baseFileName: String,
        saveLocation: SaveLocation,
        subDir: String?,
        conflictResolution: ConflictResolution,
        onProgress: ((Double) -> Void)?,
        onSuccess: (String) -> Void,
        cancellationToken: CancellationToken?
    ) throws {
        try FormatValidator.validateAudioFormat(fileType)

        // Phase 1 (0.0 → 0.5): iCloud download progress
        let downloadProgressHandler: ((Double) -> Void)? = onProgress.map { handler in
            { downloadProgress in
                handler(downloadProgress * 0.5)
            }
        }

        // Open source file with security scope and iCloud handling
        let sourceFile = try FileHelper.openSourceFile(
            at: filePath,
            onDownloadProgress: downloadProgressHandler
        )
        defer { sourceFile.close() }

        // Audio files always use Documents directory regardless of saveLocation
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

        // Phase 2 (0.5 → 1.0): Copy progress
        let copyProgressHandler: ((Double) -> Void)? = onProgress.map { handler in
            { copyProgress in
                handler(0.5 + copyProgress * 0.5)
            }
        }

        // Copy file with progress and cancellation support
        do {
            try FileHelper.copyFileWithProgress(
                from: sourceFile.handle,
                to: finalURL,
                totalSize: sourceFile.totalSize,
                onProgress: copyProgressHandler,
                cancellationToken: cancellationToken
            )
        } catch FileSaverError.cancelled {
            // Cleanup partial file on cancellation
            try? FileManager.default.removeItem(at: finalURL)
            throw FileSaverError.cancelled
        }

        onSuccess(finalURL.absoluteString)
    }
}
