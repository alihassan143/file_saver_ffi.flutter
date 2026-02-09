#if os(iOS)
import Foundation
import Photos

class PhotosHelper {
    /// Requests photo library permission from the user.
    /// Returns true if full access granted, false if limited access.
    static func requestPermission() throws -> Bool {
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

    /// Find or create album with given name
    static func findOrCreateAlbum(name: String) throws -> PHAssetCollection {
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

    /// Handle conflict resolution for Photos Library
    /// Returns existing asset URI if skip/already exists, nil otherwise
    static func handleConflictResolution(
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
#endif
