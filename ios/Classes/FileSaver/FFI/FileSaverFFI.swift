import Foundation
import DartApiDl

private var instanceCounter: UInt = 0
private var instances: [UInt: FileSaver] = [:]
private let instanceLock = NSLock()

// Cancellation token registry
private var tokenCounter: UInt = 0
private var activeTokens: [UInt: CancellationToken] = [:]
private let tokenLock = NSLock()

private func generateTokenId() -> UInt {
    tokenLock.lock()
    defer { tokenLock.unlock() }
    tokenCounter += 1
    return tokenCounter
}

private func registerToken(_ tokenId: UInt, _ token: CancellationToken) {
    tokenLock.lock()
    defer { tokenLock.unlock() }
    activeTokens[tokenId] = token
}

private func unregisterToken(_ tokenId: UInt) {
    tokenLock.lock()
    defer { tokenLock.unlock() }
    activeTokens.removeValue(forKey: tokenId)
}

private func getToken(_ tokenId: UInt) -> CancellationToken? {
    tokenLock.lock()
    defer { tokenLock.unlock() }
    return activeTokens[tokenId]
}

@_cdecl("file_saver_init_dart_api_dl")
public func fileSaverInitDartApiDL(_ data: UnsafeMutableRawPointer?) -> Int {
    guard let data = data else { return -1 }
    return Dart_InitializeApiDL(data)
}

@_cdecl("file_saver_init")
public func fileSaverInit() -> UInt {
    instanceLock.lock()
    defer { instanceLock.unlock() }

    instanceCounter += 1
    let id = instanceCounter
    instances[id] = FileSaver()

    return id
}

@_cdecl("file_saver_save_bytes")
public func fileSaverSaveBytes(
    _ instanceId: UInt,
    _ fileData: UnsafePointer<UInt8>,
    _ fileDataLength: Int64,
    _ baseFileName: UnsafePointer<CChar>,
    _ ext: UnsafePointer<CChar>,
    _ mimeType: UnsafePointer<CChar>,
    _ saveLocation: Int32,
    _ subDir: UnsafePointer<CChar>?,
    _ conflictMode: Int32,
    _ nativePort: Int64
) -> UInt {
    let reporter = ProgressReporter(port: nativePort)

    // Create cancellation token
    let tokenId = generateTokenId()
    let token = CancellationToken()
    registerToken(tokenId, token)

    // Copy data before async operation (must be done synchronously)
    let data = Data(bytes: fileData, count: Int(fileDataLength))
    let fileName = String(cString: baseFileName)
    let extStr = String(cString: ext)
    let mime = String(cString: mimeType)
    let directory = subDir.map { String(cString: $0) }

    DispatchQueue.global(qos: .userInitiated).async {
        defer { unregisterToken(tokenId) }

        // Send started event
        reporter.sendStarted()

        // Get FileSaver instance
        instanceLock.lock()
        guard let saver = instances[instanceId] else {
            instanceLock.unlock()
            reporter.sendError(
                code: Constants.errorPlatform,
                message: "FileSaver instance not found"
            )
            return
        }
        instanceLock.unlock()

        // Perform save with progress and cancellation support
        saver.saveBytes(
            fileData: data,
            baseFileName: fileName,
            extension: extStr,
            mimeType: mime,
            subDir: directory,
            saveLocationValue: Int(saveLocation),
            conflictMode: Int(conflictMode),
            reporter: reporter,
            cancellationToken: token
        )
    }

    return tokenId
}

@_cdecl("file_saver_save_file")
public func fileSaverSaveFile(
    _ instanceId: UInt,
    _ filePath: UnsafePointer<CChar>,
    _ baseFileName: UnsafePointer<CChar>,
    _ ext: UnsafePointer<CChar>,
    _ mimeType: UnsafePointer<CChar>,
    _ saveLocation: Int32,
    _ subDir: UnsafePointer<CChar>?,
    _ conflictMode: Int32,
    _ nativePort: Int64
) -> UInt {
    let reporter = ProgressReporter(port: nativePort)

    // Create cancellation token
    let tokenId = generateTokenId()
    let token = CancellationToken()
    registerToken(tokenId, token)

    // Copy strings before async operation (must be done synchronously)
    let path = String(cString: filePath)
    let fileName = String(cString: baseFileName)
    let extStr = String(cString: ext)
    let mime = String(cString: mimeType)
    let directory = subDir.map { String(cString: $0) }

    DispatchQueue.global(qos: .userInitiated).async {
        defer { unregisterToken(tokenId) }

        // Send started event
        reporter.sendStarted()

        // Get FileSaver instance
        instanceLock.lock()
        guard let saver = instances[instanceId] else {
            instanceLock.unlock()
            reporter.sendError(
                code: Constants.errorPlatform,
                message: "FileSaver instance not found"
            )
            return
        }
        instanceLock.unlock()

        // Perform save with progress and cancellation support
        saver.saveFile(
            filePath: path,
            baseFileName: fileName,
            extension: extStr,
            mimeType: mime,
            subDir: directory,
            saveLocationValue: Int(saveLocation),
            conflictMode: Int(conflictMode),
            reporter: reporter,
            cancellationToken: token
        )
    }

    return tokenId
}

@_cdecl("file_saver_cancel")
public func fileSaverCancel(_ tokenId: UInt) {
    getToken(tokenId)?.cancel()
}

@_cdecl("file_saver_dispose")
public func fileSaverDispose(_ instanceId: UInt) {
    instanceLock.lock()
    defer { instanceLock.unlock() }

    instances.removeValue(forKey: instanceId)
}
