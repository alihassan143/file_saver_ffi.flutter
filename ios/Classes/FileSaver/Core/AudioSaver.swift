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

        // Phase 1 (0.0 → 0.8): iCloud download progress
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

        // Phase 2 (0.8 → 1.0): Copy progress
        let copyProgressHandler: ((Double) -> Void)? = onProgress.map { handler in
            { copyProgress in
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

    // MARK: - Save from Network
    
    func saveNetwork(
        urlString: String,
        headers: [String: String]?,
        timeoutSeconds: Int,
        fileType: FileType,
        baseFileName: String,
        saveLocation: SaveLocation,
        subDir: String?,
        conflictResolution: ConflictResolution,
        onProgress: ((Double) -> Void)?,
        onSuccess: @escaping (String) -> Void,
        onError: @escaping (String, String) -> Void,
        onCancelled: @escaping () -> Void,
        onCancelHandlerReady: @escaping (@escaping () -> Void) -> Void,
        onComplete: @escaping () -> Void,
        cancellationToken: CancellationToken?
    ) {
        do {
            try FormatValidator.validateAudioFormat(fileType)
        } catch let error as FileSaverError {
            onError(error.code, error.message)
            onComplete()
            return
        } catch {
            onError(Constants.errorPlatform, error.localizedDescription)
            onComplete()
            return
        }
        
        saveNetworkImpl(
            urlString: urlString,
            headers: headers,
            timeoutSeconds: timeoutSeconds,
            fileType: fileType,
            baseFileName: baseFileName,
            saveLocation: saveLocation,
            subDir: subDir,
            conflictResolution: conflictResolution,
            onProgress: onProgress,
            onSuccess: onSuccess,
            onError: onError,
            onCancelled: onCancelled,
            onCancelHandlerReady: onCancelHandlerReady,
            onComplete: onComplete,
            cancellationToken: cancellationToken
        )
    }
}
