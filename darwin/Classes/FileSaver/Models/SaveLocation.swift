import Foundation

/// Represents save locations for files.
///
/// Platform-specific:
/// - iOS: Photos Library and Documents directory
/// - macOS: Downloads, Pictures, Movies, Music, and Documents directories
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
    /// ~/Downloads directory
    /// Sandbox: requires com.apple.security.files.downloads.read-write
    case downloads = 0

    /// ~/Pictures directory
    /// Sandbox: requires com.apple.security.assets.pictures.read-write
    case pictures = 1

    /// ~/Movies directory
    /// Sandbox: requires com.apple.security.assets.movies.read-write
    case movies = 2

    /// ~/Music directory
    /// Sandbox: requires com.apple.security.assets.music.read-write
    case music = 3

    /// App Container Documents directory (no entitlement needed)
    case documents = 4

    /// Converts an integer index to SaveLocation enum.
    static func fromInt(_ value: Int) -> SaveLocation {
        return SaveLocation(rawValue: value) ?? .downloads
    }

    /// Returns the URL for this save location.
    var directoryURL: URL {
        switch self {
        case .downloads:
            return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        case .pictures:
            return FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
        case .movies:
            return FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask)[0]
        case .music:
            return FileManager.default.urls(for: .musicDirectory, in: .userDomainMask)[0]
        case .documents:
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        }
    }
    #endif
}
