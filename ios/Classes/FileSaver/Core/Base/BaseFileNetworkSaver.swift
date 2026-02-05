import Foundation

// MARK: - Shared saveNetwork Implementation

extension BaseFileSaver {
    /// Default saveNetwork implementation - validates, routes to Documents or Photos
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
        
        // Route based on location + capability
        let effectiveLocation = supportsPhotosLibrary ? saveLocation : .documents
        
        switch effectiveLocation {
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
            let hasReadAccess = try PhotosHelper.requestPermission()
            
            // Check for existing file (conflict resolution)
            if let existingUri = try PhotosHelper.handleConflictResolution(
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
            
            // Save to Photos Library using hook
            let uri = try saveFileToPhotos(
                sourceURL: tmpURL,
                fileName: fileName,
                albumName: hasReadAccess ? subDir : nil,
                onProgress: { progress in
                    onProgress?(0.8 + progress * 0.2)
                }
            )
            
            cleanup()
            onProgress?(1.0)
            onSuccess(uri)
            onComplete()
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
