import Foundation
import Photos

protocol BaseFileSaver: AnyObject {
    // MARK: - Hooks for Subclasses
    
    /// Format validation hook - override in subclasses to validate file type
    /// Default implementation does nothing (no validation)
    func validateFormat(_ fileType: FileType) throws
    
    /// Whether this saver supports Photos Library saves
    /// Default is false (Documents only)
    var supportsPhotosLibrary: Bool { get }
    
    /// Save data to Photos Library - only Image/Video override this
    /// Default implementation throws unsupportedFormat error
    func saveBytesToPhotos(
        fileData: Data,
        fileName: String,
        albumName: String?,
        onProgress: ((Double) -> Void)?
    ) throws -> String
    
    /// Save file to Photos Library - only Image/Video override this
    /// Default implementation throws unsupportedFormat error
    func saveFileToPhotos(
        sourceURL: URL,
        fileName: String,
        albumName: String?,
        onProgress: ((Double) -> Void)?
    ) throws -> String
    
    // MARK: - Core Methods (Required)
    
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

// MARK: - Default Hook Implementations

extension BaseFileSaver {
    /// Default: no format validation
    func validateFormat(_ fileType: FileType) throws { }
    
    /// Default: Documents only (no Photos support)
    var supportsPhotosLibrary: Bool { false }
    
    /// Default: Photos not supported
    func saveBytesToPhotos(
        fileData: Data,
        fileName: String,
        albumName: String?,
        onProgress: ((Double) -> Void)?
    ) throws -> String {
        throw FileSaverError.unsupportedFormat("This file type cannot be saved to Photos Library")
    }
    
    /// Default: Photos not supported
    func saveFileToPhotos(
        sourceURL: URL,
        fileName: String,
        albumName: String?,
        onProgress: ((Double) -> Void)?
    ) throws -> String {
        throw FileSaverError.unsupportedFormat("This file type cannot be saved to Photos Library")
    }
}

// MARK: - Shared saveBytes Implementation

extension BaseFileSaver {
    /// Default saveBytes implementation - validates, routes to Documents or Photos
    func saveBytesImpl(
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
        // Validate format (hook)
        try validateFormat(fileType)
        
        // Validate data
        try validateFileData(fileData)
        
        let fileName = buildFileName(base: baseFileName, extension: fileType.ext)
        
        // Route based on location + capability
        let effectiveLocation = supportsPhotosLibrary ? saveLocation : .documents
        
        switch effectiveLocation {
        case .documents:
            let uri = try saveBytesToDocumentsImpl(
                fileData: fileData,
                fileName: fileName,
                subDir: subDir,
                conflictResolution: conflictResolution,
                onProgress: onProgress,
                cancellationToken: cancellationToken
            )
            onSuccess(uri)
            
        case .photos:
            // Photos Library API doesn't support progress, report 0 → 1
            onProgress?(0.0)
            
            let hasReadAccess = try requestPhotosPermission()
            
            if let existingUri = try handlePhotosConflictResolution(
                fileName: fileName,
                subDir: subDir,
                conflictResolution: conflictResolution,
                hasReadAccess: hasReadAccess
            ) {
                onProgress?(1.0)
                onSuccess(existingUri)
                return
            }
            
            let uri = try saveBytesToPhotos(
                fileData: fileData,
                fileName: fileName,
                albumName: hasReadAccess ? subDir : nil,
                onProgress: onProgress
            )
            onProgress?(1.0)
            onSuccess(uri)
        }
    }
    
    /// Save bytes to Documents directory
    private func saveBytesToDocumentsImpl(
        fileData: Data,
        fileName: String,
        subDir: String?,
        conflictResolution: ConflictResolution,
        onProgress: ((Double) -> Void)?,
        cancellationToken: CancellationToken?
    ) throws -> String {
        var targetDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        if let subDir = subDir {
            targetDir = targetDir.appendingPathComponent(subDir)
        }
        
        try FileHelper.ensureDirectoryExists(at: targetDir)
        
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
            try? FileManager.default.removeItem(at: finalURL)
            throw FileSaverError.cancelled
        }
        
        return finalURL.absoluteString
    }
}

// MARK: - Shared saveFile Implementation

extension BaseFileSaver {
    /// Default saveFile implementation - validates, routes to Documents or Photos
    func saveFileImpl(
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
        // Validate format (hook)
        try validateFormat(fileType)
        
        let fileName = buildFileName(base: baseFileName, extension: fileType.ext)
        
        // Route based on location + capability
        let effectiveLocation = supportsPhotosLibrary ? saveLocation : .documents
        
        switch effectiveLocation {
        case .documents:
            let uri = try saveFileToDocumentsImpl(
                filePath: filePath,
                fileName: fileName,
                subDir: subDir,
                conflictResolution: conflictResolution,
                onProgress: onProgress,
                cancellationToken: cancellationToken
            )
            onSuccess(uri)
            
        case .photos:
            // Phase 1 (0.0 → 0.8): iCloud download progress
            let downloadProgressHandler: ((Double) -> Void)? = onProgress.map { handler in
                { downloadProgress in
                    handler(downloadProgress * 0.8)
                }
            }
            
            let hasReadAccess = try requestPhotosPermission()
            
            if let existingUri = try handlePhotosConflictResolution(
                fileName: fileName,
                subDir: subDir,
                conflictResolution: conflictResolution,
                hasReadAccess: hasReadAccess
            ) {
                onProgress?(1.0)
                onSuccess(existingUri)
                return
            }
            
            // Open source file with iCloud download progress
            let sourceFile = try FileHelper.openSourceFile(
                at: filePath,
                onDownloadProgress: downloadProgressHandler
            )
            defer { sourceFile.close() }
            
            // Phase 2 (0.8 → 1.0): Photos Library save (no granular progress available)
            onProgress?(0.8)
            
            let uri = try saveFileToPhotos(
                sourceURL: sourceFile.url,
                fileName: fileName,
                albumName: hasReadAccess ? subDir : nil,
                onProgress: onProgress
            )
            onProgress?(1.0)
            onSuccess(uri)
        }
    }
    
    /// Save file to Documents directory
    private func saveFileToDocumentsImpl(
        filePath: String,
        fileName: String,
        subDir: String?,
        conflictResolution: ConflictResolution,
        onProgress: ((Double) -> Void)?,
        cancellationToken: CancellationToken?
    ) throws -> String {
        // Phase 1 (0.0 → 0.8): iCloud download progress
        let downloadProgressHandler: ((Double) -> Void)? = onProgress.map { handler in
            { downloadProgress in
                handler(downloadProgress * 0.8)
            }
        }
        
        // Open source file with security scope and iCloud handling
        let sourceFile = try FileHelper.openSourceFile(
            at: filePath,
            onDownloadProgress: downloadProgressHandler
        )
        defer { sourceFile.close() }
        
        var targetDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        if let subDir = subDir {
            targetDir = targetDir.appendingPathComponent(subDir)
        }
        
        try FileHelper.ensureDirectoryExists(at: targetDir)
        
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
            try? FileManager.default.removeItem(at: finalURL)
            throw FileSaverError.cancelled
        }
        
        return finalURL.absoluteString
    }
}

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

// MARK: - Helper Methods

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
    func requestPhotosPermission() throws -> Bool {
        if #available(iOS 14, *) {
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
                Thread.sleep(forTimeInterval: 0.5)
            }
            
            guard status == .authorized || status == .limited else {
                throw FileSaverError.permissionDenied("Photo library access denied")
            }
            
            return status == .authorized
        } else {
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
                Thread.sleep(forTimeInterval: 0.5)
            }
            
            guard status == .authorized else {
                throw FileSaverError.permissionDenied("Photo library access denied")
            }
            
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
}
