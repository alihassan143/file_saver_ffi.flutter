import Foundation

class FileSaver {
    let imageSaver = ImageSaver()
    let videoSaver = VideoSaver()
    let audioSaver = AudioSaver()
    let customFileSaver = CustomFileSaver()

    // MARK: - Standard Save Methods

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
        guard let conflictResolution = parseConflictResolution(conflictMode, reporter: reporter) else { return }

        let fileType = FileHelper.getFileType(ext: ext, mimeType: mimeType)
        let saveLocation = SaveLocation.fromInt(saveLocationValue)
        let saver = getSaver(for: fileType)

        do {
            try saver.saveBytes(
                fileData: fileData,
                fileType: fileType,
                baseFileName: baseFileName,
                saveLocation: saveLocation,
                subDir: subDir,
                conflictResolution: conflictResolution,
                onProgress: { reporter.sendProgress($0) },
                onSuccess: { reporter.sendSuccess(uri: $0) },
                cancellationToken: cancellationToken
            )
        } catch {
            handleError(error, reporter: reporter)
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
        guard let conflictResolution = parseConflictResolution(conflictMode, reporter: reporter) else { return }

        let fileType = FileHelper.getFileType(ext: ext, mimeType: mimeType)
        let saveLocation = SaveLocation.fromInt(saveLocationValue)
        let saver = getSaver(for: fileType)

        do {
            try saver.saveFile(
                filePath: filePath,
                fileType: fileType,
                baseFileName: baseFileName,
                saveLocation: saveLocation,
                subDir: subDir,
                conflictResolution: conflictResolution,
                onProgress: { reporter.sendProgress($0) },
                onSuccess: { reporter.sendSuccess(uri: $0) },
                cancellationToken: cancellationToken
            )
        } catch {
            handleError(error, reporter: reporter)
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
        guard let conflictResolution = parseConflictResolution(conflictMode, reporter: reporter, onComplete: onComplete) else { return }

        let fileType = FileHelper.getFileType(ext: ext, mimeType: mimeType)
        let saveLocation = SaveLocation.fromInt(saveLocationValue)
        let saver = getSaver(for: fileType)

        saver.saveNetwork(
            urlString: urlString,
            headers: headers,
            timeoutSeconds: timeoutSeconds,
            fileType: fileType,
            baseFileName: baseFileName,
            saveLocation: saveLocation,
            subDir: subDir,
            conflictResolution: conflictResolution,
            onProgress: { reporter.sendProgress($0) },
            onSuccess: { reporter.sendSuccess(uri: $0) },
            onError: { reporter.sendError(code: $0, message: $1) },
            onCancelled: { reporter.sendCancelled() },
            onCancelHandlerReady: onCancelHandlerReady,
            onComplete: onComplete,
            cancellationToken: cancellationToken
        )
    }

    // MARK: - Save*As Methods (User-Selected Directory)

    func saveBytesAs(
        fileData: Data,
        directoryUri: String,
        baseFileName: String,
        extension ext: String,
        conflictMode: Int,
        reporter: ProgressReporter,
        cancellationToken: CancellationToken? = nil
    ) {
        guard let conflictResolution = parseConflictResolution(conflictMode, reporter: reporter) else { return }
        guard let directoryURL = parseDirectoryURL(directoryUri, reporter: reporter) else { return }

        let fileName = FileHelper.buildFileName(fileName: baseFileName, extension: ext)

        do {
            try customFileSaver.saveBytesAs(
                fileData: fileData,
                directoryURL: directoryURL,
                fileName: fileName,
                conflictResolution: conflictResolution,
                onProgress: { reporter.sendProgress($0) },
                onSuccess: { reporter.sendSuccess(uri: $0) },
                cancellationToken: cancellationToken
            )
        } catch {
            handleError(error, reporter: reporter)
        }
    }

    func saveFileAs(
        filePath: String,
        directoryUri: String,
        baseFileName: String,
        extension ext: String,
        conflictMode: Int,
        reporter: ProgressReporter,
        cancellationToken: CancellationToken? = nil
    ) {
        guard let conflictResolution = parseConflictResolution(conflictMode, reporter: reporter) else { return }
        guard let directoryURL = parseDirectoryURL(directoryUri, reporter: reporter) else { return }

        let fileName = FileHelper.buildFileName(fileName: baseFileName, extension: ext)

        do {
            try customFileSaver.saveFileAs(
                filePath: filePath,
                directoryURL: directoryURL,
                fileName: fileName,
                conflictResolution: conflictResolution,
                onProgress: { reporter.sendProgress($0) },
                onSuccess: { reporter.sendSuccess(uri: $0) },
                cancellationToken: cancellationToken
            )
        } catch {
            handleError(error, reporter: reporter)
        }
    }

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
        guard let conflictResolution = parseConflictResolution(conflictMode, reporter: reporter, onComplete: onComplete) else { return }
        guard let directoryURL = parseDirectoryURL(directoryUri, reporter: reporter, onComplete: onComplete) else { return }

        let fileName = FileHelper.buildFileName(fileName: baseFileName, extension: ext)

        customFileSaver.saveNetworkAs(
            urlString: urlString,
            headers: headers,
            timeoutSeconds: timeoutSeconds,
            directoryURL: directoryURL,
            fileName: fileName,
            conflictResolution: conflictResolution,
            onProgress: { reporter.sendProgress($0) },
            onSuccess: { reporter.sendSuccess(uri: $0) },
            onError: { reporter.sendError(code: $0, message: $1) },
            onCancelled: { reporter.sendCancelled() },
            onCancelHandlerReady: onCancelHandlerReady,
            onComplete: onComplete,
            cancellationToken: cancellationToken
        )
    }

    // MARK: - Private Helpers

    private func parseConflictResolution(
        _ conflictMode: Int,
        reporter: ProgressReporter,
        onComplete: (() -> Void)? = nil
    ) -> ConflictResolution? {
        guard let resolution = ConflictResolution(rawValue: conflictMode) else {
            reporter.sendError(
                code: Constants.errorPlatform,
                message: "Invalid conflict resolution mode: \(conflictMode)"
            )
            onComplete?()
            return nil
        }
        return resolution
    }

    private func getSaver(for fileType: FileType) -> BaseFileSaver {
        switch fileType.category {
        case .image: return imageSaver
        case .video: return videoSaver
        case .audio: return audioSaver
        case .custom: return customFileSaver
        }
    }

    private func parseDirectoryURL(
        _ directoryUri: String,
        reporter: ProgressReporter,
        onComplete: (() -> Void)? = nil
    ) -> URL? {
        guard let url = URL(string: directoryUri) else {
            reporter.sendError(
                code: Constants.errorInvalidInput,
                message: "Invalid directory URI: \(directoryUri)"
            )
            onComplete?()
            return nil
        }
        return url
    }

    private func handleError(_ error: Error, reporter: ProgressReporter) {
        switch error {
        case FileSaverError.cancelled:
            reporter.sendCancelled()
        case let fsError as FileSaverError:
            reporter.sendError(code: fsError.code, message: fsError.message)
        default:
            reporter.sendError(
                code: Constants.errorPlatform,
                message: "Unexpected error: \(error.localizedDescription)"
            )
        }
    }
}
