import Foundation

/// A script that fills a workspace with a fixed set of windows, listed in
/// the Start menu.
struct WorkspaceLayoutScript: Identifiable, Hashable {
    let url: URL

    var id: String { url.path }

    /// File name without extension, dashes and underscores as spaces,
    /// e.g. `terminal-finder-preview` becomes "Terminal finder preview".
    var name: String {
        let words = url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }
}
