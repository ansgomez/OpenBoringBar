import Foundation

/// Finds and runs workspace layout scripts: the executable files in
/// `~/.config/openboringbar/layouts`.
enum WorkspaceLayoutProvider {
    static var directoryURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/openboringbar/layouts", isDirectory: true)
    }

    /// Executable files in the layouts folder, by name. Empty when the
    /// folder does not exist.
    static func layouts(fileManager: FileManager = .default) -> [WorkspaceLayoutScript] {
        let urls = (try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return urls
            .filter { url in
                (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
                    && fileManager.isExecutableFile(atPath: url.path)
            }
            .map(WorkspaceLayoutScript.init(url:))
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Starts the script with the workspace name as its only argument (none
    /// when unknown) and does not wait for it. `completion` runs on the main
    /// thread when the script ends, with `false` if it failed or could not
    /// start.
    static func run(
        _ layout: WorkspaceLayoutScript,
        workspace: String?,
        completion: @escaping (Bool) -> Void
    ) {
        let process = Process()
        process.executableURL = layout.url
        process.arguments = workspace.map { [$0] } ?? []
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { finished in
            let succeeded = finished.terminationStatus == 0
            DispatchQueue.main.async { completion(succeeded) }
        }
        do {
            try process.run()
        } catch {
            NSLog("OpenBoringBar: could not run layout \(layout.url.path): \(error.localizedDescription)")
            DispatchQueue.main.async { completion(false) }
        }
    }

    /// Creates the layouts folder if needed and returns it.
    static func ensureDirectory(fileManager: FileManager = .default) -> URL {
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }
}
