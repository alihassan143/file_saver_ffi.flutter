import Foundation

class FileSaver {
    let imageSaver = ImageSaver()
    let videoSaver = VideoSaver()
    let audioSaver = AudioSaver()
    let customFileSaver = CustomFileSaver()

    /// Saves file bytes with progress reporting via ProgressReporter
    func saveBytes(
        fileData: Data,
        baseFileName: String,
        extension ext: String,
        mimeType: String,
        subDir: String?,
        saveLocationValue: Int,
        conflictMode: Int,
        reporter: ProgressReporter
    ) {
        do {
            let fileType = FileHelper.getFileType(ext: ext, mimeType: mimeType)

            guard let conflictResolution = ConflictResolution(rawValue: conflictMode) else {
                reporter.sendError(
                    code: Constants.errorPlatform,
                    message: "Invalid conflict resolution mode: \(conflictMode)"
                )
                return
            }

            let saveLocation = SaveLocation.fromInt(saveLocationValue)

            let saver: BaseFileSaver
            switch fileType.category {
            case .image:
                saver = imageSaver
            case .video:
                saver = videoSaver
            case .audio:
                saver = audioSaver
            case .custom:
                saver = customFileSaver
            }

            let result = try saver.saveBytes(
                fileData: fileData,
                fileType: fileType,
                baseFileName: baseFileName,
                saveLocation: saveLocation,
                subDir: subDir,
                conflictResolution: conflictResolution,
                onProgress: { progress in
                    reporter.sendProgress(progress)
                }
            )

            switch result {
            case .success(_, let fileUri):
                reporter.sendSuccess(uri: fileUri)
            case .failure(let errorCode, let message):
                reporter.sendError(code: errorCode, message: message)
            }
        } catch let error as FileSaverError {
            reporter.sendError(code: error.code, message: error.message)
        } catch {
            reporter.sendError(
                code: Constants.errorPlatform,
                message: "Unexpected error: \(error.localizedDescription)"
            )
        }
    }
}
