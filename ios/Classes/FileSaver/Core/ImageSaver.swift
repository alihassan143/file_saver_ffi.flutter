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
        onProgress: ((Double) -> Void)?
    ) throws -> SaveResult {
        try FormatValidator.validateImageFormat(fileType)
        try validateFileData(fileData)

        let fileName = buildFileName(base: baseFileName, extension: fileType.ext)

        switch saveLocation {
        case .photos:
            // Photos Library API doesn't support progress, report 0 → 1
            onProgress?(0.0)

            let hasReadAccess = try requestPhotosPermission()

            if let result = try handlePhotosConflictResolution(
                fileName: fileName,
                subDir: subDir,
                conflictResolution: conflictResolution,
                hasReadAccess: hasReadAccess
            ) {
                onProgress?(1.0)
                return result
            }

            let result = try saveToPhotosLibrary(
                imageData: fileData,
                fileName: fileName,
                albumName: hasReadAccess ? subDir : nil
            )
            onProgress?(1.0)
            return result

        case .documents:
            return try saveToDocuments(
                imageData: fileData,
                fileName: fileName,
                subDir: subDir,
                conflictResolution: conflictResolution,
                onProgress: onProgress
            )
        }
    }

    private func saveToPhotosLibrary(imageData: Data, fileName: String, albumName: String?) throws -> SaveResult {
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

        return .success(filePath: assetId, fileUri: "ph://\(assetId)")
    }

    private func saveToDocuments(
        imageData: Data,
        fileName: String,
        subDir: String?,
        conflictResolution: ConflictResolution,
        onProgress: ((Double) -> Void)?
    ) throws -> SaveResult {
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

        try FileHelper.writeFileWithProgress(data: imageData, to: finalURL, onProgress: onProgress)

        return .success(filePath: finalURL.path, fileUri: finalURL.absoluteString)
    }
}
