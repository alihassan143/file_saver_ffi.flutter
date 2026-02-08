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
    
    /// Saves file from network URL with progress reporting via ProgressReporter
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
            onComplete()
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

        saver.saveNetwork(
            urlString: urlString,
            headers: headers,
            timeoutSeconds: timeoutSeconds,
            fileType: fileType,
            baseFileName: baseFileName,
            saveLocation: saveLocation,
            subDir: subDir,
            conflictResolution: conflictResolution,
            onProgress: { progress in
                reporter.sendProgress(progress)
            },
            onSuccess: { uri in
                reporter.sendSuccess(uri: uri)
            },
            onError: { code, message in
                reporter.sendError(code: code, message: message)
            },
            onCancelled: {
                reporter.sendCancelled()
            },
            onCancelHandlerReady: onCancelHandlerReady,
            onComplete: onComplete,
            cancellationToken: cancellationToken
        )
    }

    // MARK: - Save*As Methods (User-Selected Directory)

    /// Save bytes to user-selected directory
    func saveBytesAs(
        fileData: Data,
        directoryUri: String,
        baseFileName: String,
        extension ext: String,
        conflictMode: Int,
        reporter: ProgressReporter,
        cancellationToken: CancellationToken? = nil
    ) {
        do {
            guard let conflictResolution = ConflictResolution(rawValue: conflictMode) else {
                reporter.sendError(
                    code: Constants.errorPlatform,
                    message: "Invalid conflict resolution mode: \(conflictMode)"
                )
                return
            }

            guard let directoryURL = URL(string: directoryUri) else {
                reporter.sendError(
                    code: Constants.errorInvalidInput,
                    message: "Invalid directory URI: \(directoryUri)"
                )
                return
            }

            let fileName = FileHelper.buildFileName(fileName: baseFileName, extension: ext)

            try customFileSaver.saveBytesAs(
                fileData: fileData,
                directoryURL: directoryURL,
                fileName: fileName,
                conflictResolution: conflictResolution,
                onProgress: { progress in
                    reporter.sendProgress(progress)
                },
                onSuccess: { uri in
                    reporter.sendSuccess(uri: uri)
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

    /// Save file to user-selected directory
    func saveFileAs(
        filePath: String,
        directoryUri: String,
        baseFileName: String,
        extension ext: String,
        conflictMode: Int,
        reporter: ProgressReporter,
        cancellationToken: CancellationToken? = nil
    ) {
        do {
            guard let conflictResolution = ConflictResolution(rawValue: conflictMode) else {
                reporter.sendError(
                    code: Constants.errorPlatform,
                    message: "Invalid conflict resolution mode: \(conflictMode)"
                )
                return
            }

            guard let directoryURL = URL(string: directoryUri) else {
                reporter.sendError(
                    code: Constants.errorInvalidInput,
                    message: "Invalid directory URI: \(directoryUri)"
                )
                return
            }

            let fileName = FileHelper.buildFileName(fileName: baseFileName, extension: ext)

            try customFileSaver.saveFileAs(
                filePath: filePath,
                directoryURL: directoryURL,
                fileName: fileName,
                conflictResolution: conflictResolution,
                onProgress: { progress in
                    reporter.sendProgress(progress)
                },
                onSuccess: { uri in
                    reporter.sendSuccess(uri: uri)
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

    /// Save network file to user-selected directory
    func saveNetworkAs(
        urlString: String,
        headers: [String: String]?,
        timeoutSeconds: Int,
        directoryUri: String,
        baseFileName: String,
        extension ext: String,
        conflictMode: Int,
        reporter: ProgressReporter,
        cancellationToken: CancellationToken? = nil,
        onCancelHandlerReady: @escaping (@escaping () -> Void) -> Void,
        onComplete: @escaping () -> Void
    ) {
        guard let conflictResolution = ConflictResolution(rawValue: conflictMode) else {
            reporter.sendError(
                code: Constants.errorPlatform,
                message: "Invalid conflict resolution mode: \(conflictMode)"
            )
            onComplete()
            return
        }

        guard let directoryURL = URL(string: directoryUri) else {
            reporter.sendError(
                code: Constants.errorInvalidInput,
                message: "Invalid directory URI: \(directoryUri)"
            )
            onComplete()
            return
        }

        let fileName = FileHelper.buildFileName(fileName: baseFileName, extension: ext)

        customFileSaver.saveNetworkAs(
            urlString: urlString,
            headers: headers,
            timeoutSeconds: timeoutSeconds,
            directoryURL: directoryURL,
            fileName: fileName,
            conflictResolution: conflictResolution,
            onProgress: { progress in
                reporter.sendProgress(progress)
            },
            onSuccess: { uri in
                reporter.sendSuccess(uri: uri)
            },
            onError: { code, message in
                reporter.sendError(code: code, message: message)
            },
            onCancelled: {
                reporter.sendCancelled()
            },
            onCancelHandlerReady: onCancelHandlerReady,
            onComplete: onComplete,
            cancellationToken: cancellationToken
        )
    }
}
