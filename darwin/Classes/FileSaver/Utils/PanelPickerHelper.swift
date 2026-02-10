#if os(macOS)
import AppKit

/// Helper for NSOpenPanel operations on macOS.
///
/// Provides a simple async interface for picking directories via the system panel.
class PanelPickerHelper {
    /// Pick a directory using the system open panel.
    ///
    /// - Parameter completion: Called with the selected directory URL, or nil if cancelled
    static func pickDirectory(completion: @escaping (URL?) -> Void) {
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.canCreateDirectories = true
            panel.allowsMultipleSelection = false
            panel.prompt = "Select"
            panel.message = "Choose a directory to save files"

            if panel.runModal() == .OK {
                completion(panel.url)
            } else {
                completion(nil)
            }
        }
    }
}
#endif
