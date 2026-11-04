import AppKit

protocol ApplicationLocating {
    func fileExists(at url: URL) -> Bool
    func bundleIdentifier(at url: URL) -> String?
    func applicationURL(forBundleIdentifier bundleIdentifier: String) -> URL?
}

/// Finds apps on disk through FileManager, Bundle, and Launch Services.
final class ApplicationLocationProvider: ApplicationLocating {
    func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    func bundleIdentifier(at url: URL) -> String? {
        Bundle(url: url)?.bundleIdentifier
    }

    func applicationURL(forBundleIdentifier bundleIdentifier: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }
}
