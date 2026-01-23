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
        onProgress: ((Double) -> Void)?
    ) throws -> SaveResult {
        try FormatValidator.validateVideoFormat(fileType)
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
                videoData: fileData,
                fileName: fileName,
                fileExtension: fileType.ext,
                albumName: hasReadAccess ? subDir : nil
            )
            onProgress?(1.0)
            return result

        case .documents:
            return try saveToDocuments(
                videoData: fileData,
                fileName: fileName,
                subDir: subDir,
                conflictResolution: conflictResolution,
                onProgress: onProgress
            )
        }
    }

    private func saveToPhotosLibrary(videoData: Data, fileName: String, fileExtension: String, albumName: String?) throws -> SaveResult {
        let tempFileName = "\(UUID().uuidString).\(fileExtension)"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(tempFileName)
        try videoData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let album = try albumName.map { try findOrCreateAlbum(name: $0) }

        var assetId: String?

        do {
            try PHPhotoLibrary.shared().performChangesAndWait {
                let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: tempURL)

                if let album = album {
                    if let placeholder = request?.placeholderForCreatedAsset {
                        let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
                        albumChangeRequest?.addAssets([placeholder] as NSArray)
                    }
                }

                assetId = request?.placeholderForCreatedAsset?.localIdentifier
            }
        } catch {
            throw FileSaverError.fileIO("Failed to save video: \(error.localizedDescription)")
        }

        guard let assetId = assetId else {
            throw FileSaverError.fileIO("Failed to save video to Photos library")
        }

        return .success(filePath: assetId, fileUri: "ph://\(assetId)")
    }

    private func saveToDocuments(
        videoData: Data,
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

        try FileHelper.writeFileWithProgress(data: videoData, to: finalURL, onProgress: onProgress)

        return .success(filePath: finalURL.path, fileUri: finalURL.absoluteString)
    }
}
