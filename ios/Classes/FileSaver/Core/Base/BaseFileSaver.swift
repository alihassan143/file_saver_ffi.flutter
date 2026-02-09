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
    func validateFormat(_ fileType: FileType) throws {}

    var supportsPhotosLibrary: Bool { false }

    func saveBytesToPhotos(
        fileData: Data,
        fileName: String,
        albumName: String?,
        onProgress: ((Double) -> Void)?
    ) throws -> String {
        throw FileSaverError.unsupportedFormat("This file type cannot be saved to Photos Library")
    }

    func saveFileToPhotos(
        sourceURL: URL,
        fileName: String,
        albumName: String?,
        onProgress: ((Double) -> Void)?
    ) throws -> String {
        throw FileSaverError.unsupportedFormat("This file type cannot be saved to Photos Library")
    }
}

// MARK: - Helper Methods

extension BaseFileSaver {
    func validateFileData(_ fileData: Data) throws {
        guard !fileData.isEmpty else {
            throw FileSaverError.invalidInput("File data is empty")
        }
    }

    func buildFileName(base: String, extension ext: String) -> String {
        return FileHelper.buildFileName(fileName: base, extension: ext)
    }

    func findOrCreateAlbum(name: String) throws -> PHAssetCollection {
        return try PhotosHelper.findOrCreateAlbum(name: name)
    }

    /// Resolves Documents directory with optional subdirectory
    func resolveDocumentsDirectory(subDir: String?) throws -> URL {
        var targetDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        if let subDir = subDir {
            targetDir = targetDir.appendingPathComponent(subDir)
        }
        try FileHelper.ensureDirectoryExists(at: targetDir)
        return targetDir
    }

    /// Creates progress mapper for phase-based progress reporting
    func progressMapper(
        from onProgress: ((Double) -> Void)?,
        startProgress: Double,
        endProgress: Double
    ) -> ((Double) -> Void)? {
        return onProgress.map { handler in
            { phaseProgress in
                handler(startProgress + phaseProgress * (endProgress - startProgress))
            }
        }
    }

    /// Handles Photos permission and conflict resolution
    /// Returns (hasReadAccess, existingUri) where existingUri is non-nil if file should be skipped
    func handlePhotosSetup(
        fileName: String,
        subDir: String?,
        conflictResolution: ConflictResolution
    ) throws -> (hasReadAccess: Bool, existingUri: String?) {
        let hasReadAccess = try PhotosHelper.requestPermission(needAlbum: subDir != nil)
        let existingUri = try PhotosHelper.handleConflictResolution(
            fileName: fileName,
            subDir: subDir,
            conflictResolution: conflictResolution,
            hasReadAccess: hasReadAccess
        )
        return (hasReadAccess, existingUri)
    }
}

// MARK: - Shared saveBytes Implementation

extension BaseFileSaver {
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
        try validateFormat(fileType)
        try validateFileData(fileData)

        let fileName = buildFileName(base: baseFileName, extension: fileType.ext)
        let effectiveLocation = supportsPhotosLibrary ? saveLocation : .documents

        switch effectiveLocation {
        case .documents:
            let targetDir = try resolveDocumentsDirectory(subDir: subDir)
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

            onSuccess(finalURL.absoluteString)

        case .photos:
            onProgress?(0.0)

            let (hasReadAccess, existingUri) = try handlePhotosSetup(
                fileName: fileName,
                subDir: subDir,
                conflictResolution: conflictResolution
            )

            if let existingUri = existingUri {
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
}

// MARK: - Shared saveFile Implementation

extension BaseFileSaver {
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
        try validateFormat(fileType)

        let fileName = buildFileName(base: baseFileName, extension: fileType.ext)
        let effectiveLocation = supportsPhotosLibrary ? saveLocation : .documents

        switch effectiveLocation {
        case .documents:
            let downloadProgressHandler = progressMapper(from: onProgress, startProgress: 0.0, endProgress: 0.8)

            let sourceFile = try FileHelper.openSourceFile(
                at: filePath,
                onDownloadProgress: downloadProgressHandler
            )
            defer { sourceFile.close() }

            let targetDir = try resolveDocumentsDirectory(subDir: subDir)
            let finalURL = try FileManagerConflictResolver.resolveConflict(
                directory: targetDir,
                fileName: fileName,
                conflictResolution: conflictResolution
            )

            let copyProgressHandler = progressMapper(from: onProgress, startProgress: 0.8, endProgress: 1.0)

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

            onSuccess(finalURL.absoluteString)

        case .photos:
            let downloadProgressHandler = progressMapper(from: onProgress, startProgress: 0.0, endProgress: 0.8)

            let (hasReadAccess, existingUri) = try handlePhotosSetup(
                fileName: fileName,
                subDir: subDir,
                conflictResolution: conflictResolution
            )

            if let existingUri = existingUri {
                onProgress?(1.0)
                onSuccess(existingUri)
                return
            }

            let sourceFile = try FileHelper.openSourceFile(
                at: filePath,
                onDownloadProgress: downloadProgressHandler
            )
            defer { sourceFile.close() }

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
}
