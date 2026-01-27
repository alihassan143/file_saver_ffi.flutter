import Foundation
import Photos

class ImageSaver: BaseFileSaver {
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
        try FormatValidator.validateImageFormat(fileType)
        try validateFileData(fileData)

        let fileName = buildFileName(base: baseFileName, extension: fileType.ext)

        switch saveLocation {
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

            let uri = try saveToPhotosLibrary(
                imageData: fileData,
                fileName: fileName,
                albumName: hasReadAccess ? subDir : nil
            )
            onProgress?(1.0)
            onSuccess(uri)

        case .documents:
            let uri = try saveToDocuments(
                imageData: fileData,
                fileName: fileName,
                subDir: subDir,
                conflictResolution: conflictResolution,
                onProgress: onProgress,
                cancellationToken: cancellationToken
            )
            onSuccess(uri)
        }
    }

    private func saveToPhotosLibrary(imageData: Data, fileName: String, albumName: String?) throws -> String {
        let album = try albumName.map { try findOrCreateAlbum(name: $0) }

        var assetId: String?

        do {
            try PHPhotoLibrary.shared().performChangesAndWait {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.originalFilename = fileName
                request.addResource(with: .photo, data: imageData, options: options)

                if let album = album {
                    if let placeholder = request.placeholderForCreatedAsset {
                        let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
                        albumChangeRequest?.addAssets([placeholder] as NSArray)
                    }
                }

                assetId = request.placeholderForCreatedAsset?.localIdentifier
            }
        } catch {
            throw FileSaverError.fileIO("Failed to save image: \(error.localizedDescription)")
        }

        guard let assetId = assetId else {
            throw FileSaverError.fileIO("Failed to save image to Photos library")
        }

        return "ph://\(assetId)"
    }

    private func saveToDocuments(
        imageData: Data,
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
                data: imageData,
                to: finalURL,
                onProgress: onProgress,
                cancellationToken: cancellationToken
            )
        } catch FileSaverError.cancelled {
            // Cleanup partial file on cancellation
            try? FileManager.default.removeItem(at: finalURL)
            throw FileSaverError.cancelled
        }

        return finalURL.absoluteString
    }
    
    // MARK: - Save from File Path

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
        try FormatValidator.validateImageFormat(fileType)

        let fileName = buildFileName(base: baseFileName, extension: fileType.ext)

        switch saveLocation {
        case .photos:
            // Phase 1 (0.0 → 0.5): iCloud download progress
            let downloadProgressHandler: ((Double) -> Void)? = onProgress.map { handler in
                { downloadProgress in
                    handler(downloadProgress * 0.5)
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

            // Phase 2 (0.5 → 1.0): Photos Library save (no granular progress available)
            onProgress?(0.5)

            let uri = try saveToPhotosLibraryFromURL(
                sourceURL: sourceFile.url,
                fileName: fileName,
                albumName: hasReadAccess ? subDir : nil
            )
            onProgress?(1.0)
            onSuccess(uri)

        case .documents:
            let uri = try saveToDocumentsFromFile(
                filePath: filePath,
                fileName: fileName,
                subDir: subDir,
                conflictResolution: conflictResolution,
                onProgress: onProgress,
                cancellationToken: cancellationToken
            )
            onSuccess(uri)
        }
    }
    
    private func saveToPhotosLibraryFromURL(
        sourceURL: URL,
        fileName: String,
        albumName: String?
    ) throws -> String {
        let album = try albumName.map { try findOrCreateAlbum(name: $0) }
        
        var assetId: String?
        
        do {
            try PHPhotoLibrary.shared().performChangesAndWait {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.originalFilename = fileName
                request.addResource(with: .photo, fileURL: sourceURL, options: options)
                
                if let album = album {
                    if let placeholder = request.placeholderForCreatedAsset {
                        let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
                        albumChangeRequest?.addAssets([placeholder] as NSArray)
                    }
                }
                
                assetId = request.placeholderForCreatedAsset?.localIdentifier
            }
        } catch {
            throw FileSaverError.fileIO("Failed to save image: \(error.localizedDescription)")
        }
        
        guard let assetId = assetId else {
            throw FileSaverError.fileIO("Failed to save image to Photos library")
        }
        
        return "ph://\(assetId)"
    }
    
    private func saveToDocumentsFromFile(
        filePath: String,
        fileName: String,
        subDir: String?,
        conflictResolution: ConflictResolution,
        onProgress: ((Double) -> Void)?,
        cancellationToken: CancellationToken?
    ) throws -> String {
        // Phase 1 (0.0 → 0.5): iCloud download progress
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

        // Phase 2 (0.5 → 1.0): Copy progress
        let copyProgressHandler: ((Double) -> Void)? = onProgress.map { handler in
            { copyProgress in
                handler(0.5 + copyProgress * 0.5)
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

        return finalURL.absoluteString
    }
}
