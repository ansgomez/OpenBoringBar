import AppKit

/// App icons by bundle identifier, cached for the life of the process
/// (bundle lookups go through Launch Services and are too slow per redraw).
final class AppIconProvider {
    static let shared = AppIconProvider()

    private let cache = NSCache<NSString, NSImage>()

    func icon(forBundleIdentifier bundleIdentifier: String?) -> NSImage {
        guard let bundleIdentifier else {
            return Self.genericIcon
        }
        if let cached = cache.object(forKey: bundleIdentifier as NSString) {
            return cached
        }
        let icon = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
            .map { NSWorkspace.shared.icon(forFile: $0.path) } ?? Self.genericIcon
        cache.setObject(icon, forKey: bundleIdentifier as NSString)
        return icon
    }

    private static var genericIcon: NSImage {
        NSWorkspace.shared.icon(for: .applicationBundle)
    }
}
