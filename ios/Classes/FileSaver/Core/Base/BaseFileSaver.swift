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
            
            let hasReadAccess = try PhotosHelper.requestPermission()
            
            if let existingUri = try PhotosHelper.handleConflictResolution(
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
            
            let hasReadAccess = try PhotosHelper.requestPermission()
            
            if let existingUri = try PhotosHelper.handleConflictResolution(
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
    
    /// Find or create album with given name (used by ImageSaver/VideoSaver)
    func findOrCreateAlbum(name: String) throws -> PHAssetCollection {
        return try PhotosHelper.findOrCreateAlbum(name: name)
    }
}
