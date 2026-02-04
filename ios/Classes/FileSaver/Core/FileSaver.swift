import Foundation

class FileSaver {
    let imageSaver = ImageSaver()
    let videoSaver = VideoSaver()
    let audioSaver = AudioSaver()
    let customFileSaver = CustomFileSaver()

    func saveBytes(
        fileData: Data,
        baseFileName: String,
        extension ext: String,
        mimeType: String,
        subDir: String?,
        saveLocationValue: Int,
        conflictMode: Int,
        reporter: ProgressReporter,
        cancellationToken: CancellationToken? = nil
    ) {
        do {
            let fileType = FileHelper.getFileType(ext: ext, mimeType: mimeType)

            guard let conflictResolution = ConflictResolution(rawValue: conflictMode) else {
                reporter.sendError(
                    code: Constants.errorPlatform,
                    message: "Invalid conflict resolution mode: \(conflictMode)"
                )
                return
            }

            let saveLocation = SaveLocation.fromInt(saveLocationValue)

            let saver: BaseFileSaver
            switch fileType.category {
            case .image:
                saver = imageSaver
            case .video:
                saver = videoSaver
            case .audio:
                saver = audioSaver
            case .custom:
                saver = customFileSaver
            }

            try saver.saveBytes(
                fileData: fileData,
                fileType: fileType,
                baseFileName: baseFileName,
                saveLocation: saveLocation,
                subDir: subDir,
                conflictResolution: conflictResolution,
                onProgress: { progress in
                    reporter.sendProgress(progress)
                },
                onSuccess: { fileUri in
                    reporter.sendSuccess(uri: fileUri)
                },
                cancellationToken: cancellationToken
            )
        } catch FileSaverError.cancelled {
            reporter.sendCancelled()
        } catch let error as FileSaverError {
            reporter.sendError(code: error.code, message: error.message)
        } catch {
            reporter.sendError(
                code: Constants.errorPlatform,
                message: "Unexpected error: \(error.localizedDescription)"
            )
        }
    }
    
    func saveFile(
        filePath: String,
        baseFileName: String,
        extension ext: String,
        mimeType: String,
        subDir: String?,
        saveLocationValue: Int,
        conflictMode: Int,
        reporter: ProgressReporter,
        cancellationToken: CancellationToken? = nil
    ) {
        do {
            let fileType = FileHelper.getFileType(ext: ext, mimeType: mimeType)

            guard let conflictResolution = ConflictResolution(rawValue: conflictMode) else {
                reporter.sendError(
                    code: Constants.errorPlatform,
                    message: "Invalid conflict resolution mode: \(conflictMode)"
                )
                return
            }

            let saveLocation = SaveLocation.fromInt(saveLocationValue)

            let saver: BaseFileSaver
            switch fileType.category {
            case .image:
                saver = imageSaver
            case .video:
                saver = videoSaver
            case .audio:
                saver = audioSaver
            case .custom:
                saver = customFileSaver
            }

            try saver.saveFile(
                filePath: filePath,
                fileType: fileType,
                baseFileName: baseFileName,
                saveLocation: saveLocation,
                subDir: subDir,
                conflictResolution: conflictResolution,
                onProgress: { progress in
                    reporter.sendProgress(progress)
                },
                onSuccess: { fileUri in
                    reporter.sendSuccess(uri: fileUri)
                },
                cancellationToken: cancellationToken
            )
        } catch FileSaverError.cancelled {
            reporter.sendCancelled()
        } catch let error as FileSaverError {
            reporter.sendError(code: error.code, message: error.message)
        } catch {
            reporter.sendError(
                code: Constants.errorPlatform,
                message: "Unexpected error: \(error.localizedDescription)"
            )
        }
    }
    
    func saveNetwork(
        urlString: String,
        headers: [String: String]?,
        timeoutSeconds: Int,
        baseFileName: String,
        extension ext: String,
        mimeType: String,
        subDir: String?,
        saveLocationValue: Int,
        conflictMode: Int,
        reporter: ProgressReporter,
        cancellationToken: CancellationToken? = nil,
        onCancelHandlerReady: @escaping (@escaping () -> Void) -> Void,
        onComplete: @escaping () -> Void
    ) {
        let fileType = FileHelper.getFileType(ext: ext, mimeType: mimeType)

        guard let conflictResolution = ConflictResolution(rawValue: conflictMode) else {
            reporter.sendError(
                code: Constants.errorPlatform,
                message: "Invalid conflict resolution mode: \(conflictMode)"
            )
            return
        }

        let saveLocation = SaveLocation.fromInt(saveLocationValue)
        let fileName = FileHelper.buildFileName(fileName: baseFileName, extension: fileType.ext)

            switch saveLocation {
        case .documents:
            saveNetworkToDocuments(
                urlString: urlString,
                headers: headers,
                timeoutSeconds: timeoutSeconds,
                fileName: fileName,
                subDir: subDir,
                conflictResolution: conflictResolution,
                reporter: reporter,
                cancellationToken: cancellationToken,
                onCancelHandlerReady: onCancelHandlerReady,
                onComplete: onComplete
            )

        case .photos:
            saveNetworkToPhotos(
                urlString: urlString,
                headers: headers,
                timeoutSeconds: timeoutSeconds,
                fileName: fileName,
                fileType: fileType,
                baseFileName: baseFileName,
                subDir: subDir,
                conflictResolution: conflictResolution,
                reporter: reporter,
                cancellationToken: cancellationToken,
                onCancelHandlerReady: onCancelHandlerReady,
                onComplete: onComplete
            )
        }
    }

    // MARK: - Network Save to Documents

    private func saveNetworkToDocuments(
        urlString: String,
        headers: [String: String]?,
        timeoutSeconds: Int,
        fileName: String,
        subDir: String?,
        conflictResolution: ConflictResolution,
        reporter: ProgressReporter,
        cancellationToken: CancellationToken?,
        onCancelHandlerReady: @escaping (@escaping () -> Void) -> Void,
        onComplete: @escaping () -> Void
    ) {
        // Resolve target path synchronously (no network involved)
        let finalURL: URL
        do {
            var targetDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            if let subDir = subDir {
                targetDir = targetDir.appendingPathComponent(subDir)
            }
            try FileHelper.ensureDirectoryExists(at: targetDir)

            finalURL = try FileManagerConflictResolver.resolveConflict(
                directory: targetDir,
                fileName: fileName,
                conflictResolution: conflictResolution
            )
        } catch let error as FileSaverError {
            reporter.sendError(code: error.code, message: error.message)
            onComplete()
            return
        } catch {
            reporter.sendError(code: Constants.errorPlatform, message: error.localizedDescription)
            onComplete()
            return
        }

        // Check cancellation before starting download
        if let token = cancellationToken, token.isCancelled {
            reporter.sendCancelled()
            onComplete()
            return
        }

        // Download async (non-blocking)
        NetworkHelper.downloadToFile(
            urlString: urlString,
            headers: headers,
            timeoutSeconds: timeoutSeconds,
            destinationURL: finalURL,
            onProgress: { [weak cancellationToken] (progress: Double) in
                // Check cancellation in progress callback
                if let token = cancellationToken, token.isCancelled {
                    return // Stop reporting progress, NetworkHelper will handle cancellation
                }
                reporter.sendProgress(progress)
            },
            cancellationToken: cancellationToken,
            onCancelHandlerReady: onCancelHandlerReady,
            completion: { [onComplete] (result: Result<Int64, FileSaverError>) in
                defer { onComplete() }

                switch result {
                case .success:
                    // Final cancellation check before reporting success
                    if let token = cancellationToken, token.isCancelled {
                        try? FileManager.default.removeItem(at: finalURL)
                        reporter.sendCancelled()
                        return
                    }
                    reporter.sendSuccess(uri: finalURL.absoluteString)
                case .failure(let error):
                    if case .cancelled = error {
                        reporter.sendCancelled()
                    } else {
                        reporter.sendError(code: error.code, message: error.message)
                    }
                }
            }
        )
    }

    // MARK: - Network Save to Photos

    private func saveNetworkToPhotos(
        urlString: String,
        headers: [String: String]?,
        timeoutSeconds: Int,
        fileName: String,
        fileType: FileType,
        baseFileName: String,
        subDir: String?,
        conflictResolution: ConflictResolution,
        reporter: ProgressReporter,
        cancellationToken: CancellationToken?,
        onCancelHandlerReady: @escaping (@escaping () -> Void) -> Void,
        onComplete: @escaping () -> Void
    ) {
        // Check cancellation before starting download
        if let token = cancellationToken, token.isCancelled {
            reporter.sendCancelled()
            onComplete()
            return
        }

        // Phase 1: Download to temp (0.0 → 0.8)
        NetworkHelper.downloadToTempFile(
            urlString: urlString,
            headers: headers,
            timeoutSeconds: timeoutSeconds,
            fileName: fileName,
            onProgress: { [weak cancellationToken] (downloadProgress: Double) in
                // Check cancellation in progress callback
                if let token = cancellationToken, token.isCancelled {
                    return
                }
                reporter.sendProgress(downloadProgress * 0.8)
            },
            cancellationToken: cancellationToken,
            onCancelHandlerReady: onCancelHandlerReady,
            completion: { [weak self, onComplete] (result: Result<(URL, Int64), FileSaverError>) in
                guard let self = self else {
                    onComplete()
                    return
                }

                switch result {
                case .success(let (tmpURL, _)):
                    // Check cancellation before Phase 2
                    if let token = cancellationToken, token.isCancelled {
                        try? FileManager.default.removeItem(at: tmpURL)
                        reporter.sendCancelled()
                        onComplete()
                        return
                    }

                    // Phase 2: Save to Photos (0.8 → 1.0)
                    self.saveDownloadedFileToPhotos(
                        tmpURL: tmpURL,
                        fileType: fileType,
                        baseFileName: baseFileName,
                        subDir: subDir,
                        conflictResolution: conflictResolution,
                        reporter: reporter,
                        cancellationToken: cancellationToken,
                        onComplete: onComplete
                    )

                case .failure(let error):
                    if case .cancelled = error {
                        reporter.sendCancelled()
                    } else {
                        reporter.sendError(code: error.code, message: error.message)
                    }
                    onComplete()
                }
            }
        )
    }

    private func saveDownloadedFileToPhotos(
        tmpURL: URL,
        fileType: FileType,
        baseFileName: String,
        subDir: String?,
        conflictResolution: ConflictResolution,
        reporter: ProgressReporter,
        cancellationToken: CancellationToken?,
        onComplete: @escaping () -> Void
    ) {
        // Cleanup helper - cannot use defer with async completion
        func cleanup() {
            try? FileManager.default.removeItem(at: tmpURL)
        }

        // Check cancellation before starting Photos save
        if let token = cancellationToken, token.isCancelled {
            cleanup()
            reporter.sendCancelled()
            onComplete()
            return
        }

        // Phase 2: Save to Photos (0.8 → 1.0)
        reporter.sendProgress(0.8)

        let saver: BaseFileSaver
        switch fileType.category {
        case .image: saver = imageSaver
        case .video: saver = videoSaver
        case .audio: saver = audioSaver
        case .custom: saver = customFileSaver
        }

        let fileName = FileHelper.buildFileName(fileName: baseFileName, extension: fileType.ext)

        do {
            let hasReadAccess = try saver.requestPhotosPermission()

            // Check for existing file (conflict resolution)
            if let existingUri = try saver.handlePhotosConflictResolution(
                fileName: fileName,
                subDir: subDir,
                conflictResolution: conflictResolution,
                hasReadAccess: hasReadAccess
            ) {
                cleanup()
                reporter.sendProgress(1.0)
                reporter.sendSuccess(uri: existingUri)
                onComplete()
                return
            }

            // Check cancellation before Photos Library save
            if let token = cancellationToken, token.isCancelled {
                cleanup()
                reporter.sendCancelled()
                onComplete()
                return
            }

            // Save to Photos Library
            try saver.saveFile(
                filePath: tmpURL.path,
                fileType: fileType,
                baseFileName: baseFileName,
                saveLocation: .photos,
                subDir: hasReadAccess ? subDir : nil,
                conflictResolution: conflictResolution,
                onProgress: { [weak cancellationToken] (saveProgress: Double) in
                    // Check cancellation in progress callback
                    if let token = cancellationToken, token.isCancelled {
                        return
                    }
                    // Map save progress (0.0-1.0) to (0.8-1.0)
                    reporter.sendProgress(0.8 + saveProgress * 0.2)
                },
                onSuccess: { [weak cancellationToken, onComplete] (uri: String) in
                    // Final cancellation check before success
                    if let token = cancellationToken, token.isCancelled {
                        cleanup()
                        reporter.sendCancelled()
                        onComplete()
                        return
                    }
                    cleanup()
                    reporter.sendSuccess(uri: uri)
                    onComplete()
                },
                cancellationToken: cancellationToken
            )
        } catch FileSaverError.cancelled {
            cleanup()
            reporter.sendCancelled()
            onComplete()
        } catch let error as FileSaverError {
            cleanup()
            reporter.sendError(code: error.code, message: error.message)
            onComplete()
        } catch {
            cleanup()
            reporter.sendError(code: Constants.errorPlatform, message: error.localizedDescription)
            onComplete()
        }
    }
}
