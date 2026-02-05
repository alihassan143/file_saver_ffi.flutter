import Foundation
import Photos

protocol BaseFileSaver: AnyObject {
    /// Core save method - implemented by each Saver class
    /// - Parameter onProgress: Progress callback (0.0 to 1.0), called during write operations
    /// - Parameter onSuccess: Success callback with file URI string
    /// - Parameter cancellationToken: Optional token to check for cancellation
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
    ) throws

    /// Save from source file path - reads source in chunks without loading into memory
    /// - Parameter onProgress: Progress callback (0.0 to 1.0), called during copy operations
    /// - Parameter onSuccess: Success callback with file URI string
    /// - Parameter cancellationToken: Optional token to check for cancellation
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
    ) throws

    /// Save from network URL - downloads and saves to storage
    /// - Parameter onProgress: Progress callback (0.0 to 1.0)
    /// - Parameter onSuccess: Success callback with file URI string
    /// - Parameter onError: Error callback with code and message
    /// - Parameter onCancelled: Cancellation callback
    /// - Parameter onCancelHandlerReady: Callback to receive cancel handler for direct task cancellation
    /// - Parameter onComplete: Called when operation is fully complete (for cleanup)
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
    )
}

extension BaseFileSaver {
    func validateFileData(_ fileData: Data) throws {
        guard !fileData.isEmpty else {
            throw FileSaverError.invalidFile("File data is empty")
        }
    }

    func buildFileName(base: String, extension ext: String) -> String {
        return FileHelper.buildFileName(fileName: base, extension: ext)
    }

    /// Requests photo library permission from the user.
    ///
    /// On iOS 14+, this requests `.addOnly` permission (scoped access).
    /// On iOS 13, this requests full photo library access (legacy behavior).
    ///
    /// - Returns: `true` if user has full access, `false` if limited access (iOS 14+ only)
    /// - Throws: `FileSaverError.permissionDenied` if permission is denied
    ///
    /// - Note: iOS 13 always returns `true` when permission is granted, as it only supports full access
    func requestPhotosPermission() throws -> Bool {
        if #available(iOS 14, *) {
            // iOS 14+ - Use scoped photo library access with .addOnly permission
            var status = PHPhotoLibrary.authorizationStatus(for: .addOnly)

            if status == .notDetermined {
                var result: PHAuthorizationStatus = .notDetermined
                let semaphore = DispatchSemaphore(value: 0)

                PHPhotoLibrary.requestAuthorization(for: .addOnly) { authStatus in
                    result = authStatus
                    semaphore.signal()
                }

                semaphore.wait()
                status = result

                // Small delay to ensure the status is updated
                Thread.sleep(forTimeInterval: 0.5)
            }

            guard status == .authorized || status == .limited else {
                throw FileSaverError.permissionDenied("Photo library access denied")
            }

            return status == .authorized
        } else {
            // iOS 13 fallback - Use legacy authorization API
            var status = PHPhotoLibrary.authorizationStatus()

            if status == .notDetermined {
                var result: PHAuthorizationStatus = .notDetermined
                let semaphore = DispatchSemaphore(value: 0)

                PHPhotoLibrary.requestAuthorization { authStatus in
                    result = authStatus
                    semaphore.signal()
                }

                semaphore.wait()
                status = result

                // Small delay to ensure the status is updated
                Thread.sleep(forTimeInterval: 0.5)
            }

            // iOS 13 only has .authorized status (no .limited)
            guard status == .authorized else {
                throw FileSaverError.permissionDenied("Photo library access denied")
            }

            // iOS 13 always has full access when authorized
            return true
        }
    }

    func findOrCreateAlbum(name: String) throws -> PHAssetCollection {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title = %@", name)
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: options)

        if let existing = collections.firstObject {
            return existing
        }

        var albumId: String?
        try PHPhotoLibrary.shared().performChangesAndWait {
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
            albumId = request.placeholderForCreatedAssetCollection.localIdentifier
        }

        guard let albumId = albumId,
              let album = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumId], options: nil).firstObject else {
            throw FileSaverError.fileIO("Failed to create album: \(name)")
        }

        return album
    }

    /// Handles conflict resolution for Photos Library saves
    /// - Returns: File URI if skip and file exists, nil otherwise
    func handlePhotosConflictResolution(
        fileName: String,
        subDir: String?,
        conflictResolution: ConflictResolution,
        hasReadAccess: Bool
    ) throws -> String? {
        guard hasReadAccess else {
            return nil
        }

        if conflictResolution == .skip || conflictResolution == .fail {
            if let existing = PhotosConflictResolver.findExistingAsset(fileName: fileName, inAlbum: subDir) {
                if conflictResolution == .fail {
                    throw FileSaverError.fileExists(fileName)
                }
                return "ph://\(existing.localIdentifier)"
            }
        }

        if conflictResolution == .overwrite {
            if let existing = PhotosConflictResolver.findExistingAsset(fileName: fileName, inAlbum: subDir) {
                try PhotosConflictResolver.overwriteAsset(existing)
            }
        }

        return nil
    }

    // MARK: - Default saveNetwork implementation

    /// Default implementation for network save - downloads and saves to storage
    func saveNetworkImpl(
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
        let fileName = buildFileName(base: baseFileName, extension: fileType.ext)

        switch saveLocation {
        case .documents:
            saveNetworkToDocumentsImpl(
                urlString: urlString,
                headers: headers,
                timeoutSeconds: timeoutSeconds,
                fileName: fileName,
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

        case .photos:
            saveNetworkToPhotosImpl(
                urlString: urlString,
                headers: headers,
                timeoutSeconds: timeoutSeconds,
                fileName: fileName,
                fileType: fileType,
                baseFileName: baseFileName,
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

    private func saveNetworkToDocumentsImpl(
        urlString: String,
        headers: [String: String]?,
        timeoutSeconds: Int,
        fileName: String,
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
        // Resolve target path synchronously
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
            onError(error.code, error.message)
            onComplete()
            return
        } catch {
            onError(Constants.errorPlatform, error.localizedDescription)
            onComplete()
            return
        }

        // Check cancellation before starting download
        if let token = cancellationToken, token.isCancelled {
            onCancelled()
            onComplete()
            return
        }

        NetworkHelper.downloadToFile(
            urlString: urlString,
            headers: headers,
            timeoutSeconds: timeoutSeconds,
            destinationURL: finalURL,
            onProgress: { [weak cancellationToken] (progress: Double) in
                if let token = cancellationToken, token.isCancelled { return }
                onProgress?(progress)
            },
            cancellationToken: cancellationToken,
            onCancelHandlerReady: onCancelHandlerReady,
            completion: { [onComplete, onSuccess, onError, onCancelled] (result: Result<Int64, FileSaverError>) in
                defer { onComplete() }

                switch result {
                case .success:
                    if let token = cancellationToken, token.isCancelled {
                        try? FileManager.default.removeItem(at: finalURL)
                        onCancelled()
                        return
                    }
                    onSuccess(finalURL.absoluteString)
                case .failure(let error):
                    if case .cancelled = error {
                        onCancelled()
                    } else {
                        onError(error.code, error.message)
                    }
                }
            }
        )
    }

    private func saveNetworkToPhotosImpl(
        urlString: String,
        headers: [String: String]?,
        timeoutSeconds: Int,
        fileName: String,
        fileType: FileType,
        baseFileName: String,
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
        // Check cancellation before starting download
        if let token = cancellationToken, token.isCancelled {
            onCancelled()
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
                if let token = cancellationToken, token.isCancelled { return }
                onProgress?(downloadProgress * 0.8)
            },
            cancellationToken: cancellationToken,
            onCancelHandlerReady: onCancelHandlerReady,
            completion: { [weak self, onComplete, onSuccess, onError, onCancelled] (result: Result<(URL, Int64), FileSaverError>) in
                guard let self = self else {
                    onComplete()
                    return
                }

                switch result {
                case .success(let (tmpURL, _)):
                    // Check cancellation before Phase 2
                    if let token = cancellationToken, token.isCancelled {
                        try? FileManager.default.removeItem(at: tmpURL)
                        onCancelled()
                        onComplete()
                        return
                    }

                    // Phase 2: Save to Photos (0.8 → 1.0)
                    self.saveDownloadedFileToPhotosImpl(
                        tmpURL: tmpURL,
                        fileType: fileType,
                        baseFileName: baseFileName,
                        subDir: subDir,
                        conflictResolution: conflictResolution,
                        onProgress: onProgress,
                        onSuccess: onSuccess,
                        onError: onError,
                        onCancelled: onCancelled,
                        onComplete: onComplete,
                        cancellationToken: cancellationToken
                    )

                case .failure(let error):
                    if case .cancelled = error {
                        onCancelled()
                    } else {
                        onError(error.code, error.message)
                    }
                    onComplete()
                }
            }
        )
    }

    private func saveDownloadedFileToPhotosImpl(
        tmpURL: URL,
        fileType: FileType,
        baseFileName: String,
        subDir: String?,
        conflictResolution: ConflictResolution,
        onProgress: ((Double) -> Void)?,
        onSuccess: @escaping (String) -> Void,
        onError: @escaping (String, String) -> Void,
        onCancelled: @escaping () -> Void,
        onComplete: @escaping () -> Void,
        cancellationToken: CancellationToken?
    ) {
        func cleanup() {
            try? FileManager.default.removeItem(at: tmpURL)
        }

        // Check cancellation before starting Photos save
        if let token = cancellationToken, token.isCancelled {
            cleanup()
            onCancelled()
            onComplete()
            return
        }

        // Phase 2: Save to Photos (0.8 → 1.0)
        onProgress?(0.8)

        let fileName = buildFileName(base: baseFileName, extension: fileType.ext)

        do {
            let hasReadAccess = try requestPhotosPermission()

            // Check for existing file (conflict resolution)
            if let existingUri = try handlePhotosConflictResolution(
                fileName: fileName,
                subDir: subDir,
                conflictResolution: conflictResolution,
                hasReadAccess: hasReadAccess
            ) {
                cleanup()
                onProgress?(1.0)
                onSuccess(existingUri)
                onComplete()
                return
            }

            // Check cancellation before Photos Library save
            if let token = cancellationToken, token.isCancelled {
                cleanup()
                onCancelled()
                onComplete()
                return
            }

            // Save to Photos Library using saveFile
            try saveFile(
                filePath: tmpURL.path,
                fileType: fileType,
                baseFileName: baseFileName,
                saveLocation: .photos,
                subDir: hasReadAccess ? subDir : nil,
                conflictResolution: conflictResolution,
                onProgress: { [weak cancellationToken] (saveProgress: Double) in
                    if let token = cancellationToken, token.isCancelled { return }
                    onProgress?(0.8 + saveProgress * 0.2)
                },
                onSuccess: { [weak cancellationToken, onComplete, onSuccess, onCancelled] (uri: String) in
                    if let token = cancellationToken, token.isCancelled {
                        cleanup()
                        onCancelled()
                        onComplete()
                        return
                    }
                    cleanup()
                    onSuccess(uri)
                    onComplete()
                },
                cancellationToken: cancellationToken
            )
        } catch FileSaverError.cancelled {
            cleanup()
            onCancelled()
            onComplete()
        } catch let error as FileSaverError {
            cleanup()
            onError(error.code, error.message)
            onComplete()
        } catch {
            cleanup()
            onError(Constants.errorPlatform, error.localizedDescription)
            onComplete()
        }
    }
}
