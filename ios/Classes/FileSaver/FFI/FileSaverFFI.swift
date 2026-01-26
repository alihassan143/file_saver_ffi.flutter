import Foundation
import DartApiDl

private var instanceCounter: UInt = 0
private var instances: [UInt: FileSaver] = [:]
private let instanceLock = NSLock()

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
) {
    let reporter = ProgressReporter(port: nativePort)

    DispatchQueue.global(qos: .userInitiated).async {
        // Send started event
        reporter.sendStarted()

        // Copy data before async operation
        let data = Data(bytes: fileData, count: Int(fileDataLength))
        let fileName = String(cString: baseFileName)
        let extStr = String(cString: ext)
        let mime = String(cString: mimeType)
        let directory = subDir.map { String(cString: $0) }

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

        // Perform save with progress
        saver.saveBytes(
            fileData: data,
            baseFileName: fileName,
            extension: extStr,
            mimeType: mime,
            subDir: directory,
            saveLocationValue: Int(saveLocation),
            conflictMode: Int(conflictMode),
            reporter: reporter
        )
    }
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
) {
    let reporter = ProgressReporter(port: nativePort)
    
    DispatchQueue.global(qos: .userInitiated).async {
        // Send started event
        reporter.sendStarted()
        
        // Copy strings before async operation
        let path = String(cString: filePath)
        let fileName = String(cString: baseFileName)
        let extStr = String(cString: ext)
        let mime = String(cString: mimeType)
        let directory = subDir.map { String(cString: $0) }
        
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
        
        // Perform save with progress
        saver.saveFile(
            filePath: path,
            baseFileName: fileName,
            extension: extStr,
            mimeType: mime,
            subDir: directory,
            saveLocationValue: Int(saveLocation),
            conflictMode: Int(conflictMode),
            reporter: reporter
        )
    }
}

@_cdecl("file_saver_dispose")
public func fileSaverDispose(_ instanceId: UInt) {
    instanceLock.lock()
    defer { instanceLock.unlock() }

    instances.removeValue(forKey: instanceId)
}
