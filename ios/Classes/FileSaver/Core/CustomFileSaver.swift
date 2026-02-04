import Foundation

class CustomFileSaver: BaseFileSaver {

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
        // Phase 1 (0.0 → 0.8): iCloud download progress
        let downloadProgressHandler: ((Double) -> Void)? = onProgress.map { handler in
            { downloadProgress in
                // Map download progress (0.0-1.0) to overall progress (0.0-0.8)
                handler(downloadProgress * 0.8)
            }
        }

        // Open source file with security scope and iCloud handling
        let sourceFile = try FileHelper.openSourceFile(
            at: filePath,
            onDownloadProgress: downloadProgressHandler
        )
        defer { sourceFile.close() }

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

        // Phase 2 (0.8 → 1.0): Copy progress
        let copyProgressHandler: ((Double) -> Void)? = onProgress.map { handler in
            { copyProgress in
                // Map copy progress (0.0-1.0) to overall progress (0.8-1.0)
                handler(0.8 + copyProgress * 0.2)
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
