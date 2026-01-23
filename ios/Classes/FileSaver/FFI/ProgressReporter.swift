import Foundation
import DartApiDl

/// Reports progress events to Dart via NativePort.
///
/// Message protocol:
/// - Started:    [0]
/// - Progress:   [1, progress]    // progress is 0.0 to 1.0
/// - Error:      [2, errorCode, errorMessage]
/// - Success:    [3, fileUri]
/// - Cancelled:  [4]
final class ProgressReporter {
    private let port: Int64
    private var isClosed = false

    init(port: Int64) {
        self.port = port
    }

    /// Send "started" event
    func sendStarted() {
        guard !isClosed else { return }
        sendArray([createInt(0)])
    }

    /// Send progress update (0.0 - 1.0)
    func sendProgress(_ value: Double) {
        guard !isClosed else { return }
        let clampedValue = max(0.0, min(1.0, value))
        sendArray([createInt(1), createDouble(clampedValue)])
    }

    /// Send error event
    func sendError(code: String, message: String) {
        guard !isClosed else { return }
        sendArray([createInt(2), createString(code), createString(message)])
        isClosed = true
    }

    /// Send success event with file URI
    func sendSuccess(uri: String) {
        guard !isClosed else { return }
        sendArray([createInt(3), createString(uri)])
        isClosed = true
    }

    /// Send cancelled event
    func sendCancelled() {
        guard !isClosed else { return }
        sendArray([createInt(4)])
        isClosed = true
    }

    // MARK: - Private helpers

    private func sendArray(_ elements: [UnsafeMutablePointer<Dart_CObject>]) {
        // Create array of pointers
        let arrayPtr = UnsafeMutablePointer<UnsafeMutablePointer<Dart_CObject>?>.allocate(capacity: elements.count)
        defer { arrayPtr.deallocate() }

        for (index, element) in elements.enumerated() {
            arrayPtr[index] = element
        }

        // Create array CObject
        var arrayObject = Dart_CObject()
        arrayObject.type = Dart_CObject_kArray
        arrayObject.value.as_array.length = elements.count
        arrayObject.value.as_array.values = arrayPtr

        // Send to Dart
        _ = Dart_PostCObject_DL(port, &arrayObject)

        // Clean up elements
        for element in elements {
            freeObject(element)
        }
    }

    private func createInt(_ value: Int64) -> UnsafeMutablePointer<Dart_CObject> {
        let obj = UnsafeMutablePointer<Dart_CObject>.allocate(capacity: 1)
        obj.pointee.type = Dart_CObject_kInt64
        obj.pointee.value.as_int64 = value
        return obj
    }

    private func createDouble(_ value: Double) -> UnsafeMutablePointer<Dart_CObject> {
        let obj = UnsafeMutablePointer<Dart_CObject>.allocate(capacity: 1)
        obj.pointee.type = Dart_CObject_kDouble
        obj.pointee.value.as_double = value
        return obj
    }

    private func createString(_ value: String) -> UnsafeMutablePointer<Dart_CObject> {
        let obj = UnsafeMutablePointer<Dart_CObject>.allocate(capacity: 1)
        obj.pointee.type = Dart_CObject_kString
        if let cString = strdup(value) {
            obj.pointee.value.as_string = UnsafePointer(cString)
        }
        return obj
    }

    private func freeObject(_ obj: UnsafeMutablePointer<Dart_CObject>) {
        if obj.pointee.type == Dart_CObject_kString, let str = obj.pointee.value.as_string {
            free(UnsafeMutablePointer(mutating: str))
        }
        obj.deallocate()
    }
}
