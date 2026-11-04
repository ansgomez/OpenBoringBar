import Foundation

protocol WindowWorkspaceProviding {
    /// Current window-to-workspace map, or `.empty` when no supported
    /// window manager is installed or it does not answer in time.
    func fetchSnapshot() -> WindowWorkspaceSnapshot
}

/// Reads workspaces from the AeroSpace CLI. Called on demand (when a pill's
/// menu opens); each call runs the CLI twice, about 20 ms each.
final class WindowWorkspaceProvider: WindowWorkspaceProviding {
    private static let candidatePaths = [
        "/opt/homebrew/bin/aerospace",
        "/usr/local/bin/aerospace"
    ]
    private static let timeout: TimeInterval = 0.5

    private let executableURL: URL?

    init(fileManager: FileManager = .default) {
        executableURL = Self.candidatePaths
            .first { fileManager.isExecutableFile(atPath: $0) }
            .map { URL(fileURLWithPath: $0) }
    }

    func fetchSnapshot() -> WindowWorkspaceSnapshot {
        guard executableURL != nil,
              let windowList = run(["list-windows", "--all", "--format", AeroSpaceOutputParser.windowListFormat]) else {
            return .empty
        }

        let focused = run(["list-workspaces", "--focused"])?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return WindowWorkspaceSnapshot(
            workspaceByWindowID: AeroSpaceOutputParser.workspaceByWindowID(from: windowList),
            focusedWorkspace: (focused?.isEmpty ?? true) ? nil : focused
        )
    }

    private func run(_ arguments: [String]) -> String? {
        guard let executableURL else {
            return nil
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        let deadline = Date().addingTimeInterval(Self.timeout)
        while process.isRunning && Date() < deadline {
            usleep(5_000)
        }
        if process.isRunning {
            process.terminate()
            return nil
        }

        guard process.terminationStatus == 0 else {
            return nil
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}
