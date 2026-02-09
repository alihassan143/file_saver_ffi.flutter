import Foundation

/// Represents save locations for files.
///
/// Platform-specific:
/// - iOS: Photos Library and Documents directory
/// - macOS: Documents, Downloads, and Desktop directories
enum SaveLocation: Int {
    #if os(iOS)
    /// Photos Library (requires Photos permission)
    case photos = 0

    /// Documents/ directory in app container
    case documents = 1

    /// Converts an integer index to SaveLocation enum.
    static func fromInt(_ value: Int) -> SaveLocation {
        return SaveLocation(rawValue: value) ?? .documents
    }
    #elseif os(macOS)
    /// Documents directory (~/Documents)
    case documents = 0

    /// Downloads directory (~/Downloads)
    case downloads = 1

    /// Desktop directory (~/Desktop)
    case desktop = 2

    /// Converts an integer index to SaveLocation enum.
    static func fromInt(_ value: Int) -> SaveLocation {
        return SaveLocation(rawValue: value) ?? .documents
    }

    /// Returns the URL for this save location.
    var directoryURL: URL {
        switch self {
        case .documents:
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        case .downloads:
            return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        case .desktop:
            return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        }
    }
    #endif
}
