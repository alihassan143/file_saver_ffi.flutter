import Foundation
import Photos

class VideoSaver: BaseFileSaver {
    func saveBytes(
        fileData: Data,
        fileType: FileType,
        baseFileName: String,
        saveLocation: SaveLocation,
        subDir: String?,
        conflictResolution: ConflictResolution,
        onProgress: ((Double) -> Void)?,
        onSuccess: (String) -> Void
    ) throws {
        try FormatValidator.validateVideoFormat(fileType)
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
                videoData: fileData,
                fileName: fileName,
                fileExtension: fileType.ext,
                albumName: hasReadAccess ? subDir : nil
            )
            onProgress?(1.0)
            onSuccess(uri)

        case .documents:
            let uri = try saveToDocuments(
                videoData: fileData,
                fileName: fileName,
                subDir: subDir,
                conflictResolution: conflictResolution,
                onProgress: onProgress
            )
            onSuccess(uri)
        }
    }

    private func saveToPhotosLibrary(videoData: Data, fileName: String, fileExtension: String, albumName: String?) throws -> String {
        // Videos must be saved from a file URL (not directly from data)
        // Use the actual fileName for temp file to preserve metadata
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try videoData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let album = try albumName.map { try findOrCreateAlbum(name: $0) }

        var assetId: String?

        do {
            try PHPhotoLibrary.shared().performChangesAndWait {
                let request = PHAssetCreationRequest.forAsset()

                // Use addResource with fileURL and originalFilename to preserve the file name
                let options = PHAssetResourceCreationOptions()
                options.originalFilename = fileName

                request.addResource(with: .video, fileURL: tempURL, options: options)

                if let album = album {
                    if let placeholder = request.placeholderForCreatedAsset {
                        let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
                        albumChangeRequest?.addAssets([placeholder] as NSArray)
                    }
                }

                assetId = request.placeholderForCreatedAsset?.localIdentifier
            }
        } catch {
            throw FileSaverError.fileIO("Failed to save video: \(error.localizedDescription)")
        }

        guard let assetId = assetId else {
            throw FileSaverError.fileIO("Failed to save video to Photos library")
        }

        return "ph://\(assetId)"
    }

    private func saveToDocuments(
        videoData: Data,
        fileName: String,
        subDir: String?,
        conflictResolution: ConflictResolution,
        onProgress: ((Double) -> Void)?
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

        try FileHelper.writeFileWithProgress(data: videoData, to: finalURL, onProgress: onProgress)

        return finalURL.absoluteString
    }
    }
}
