import CoreGraphics
import Foundation

protocol AeroSpaceControlling {
    /// `true` when the `aerospace` CLI was found.
    var isAvailable: Bool { get }
    /// Current state, or `.empty` when AeroSpace is missing or does not answer.
    func fetchState() -> AeroSpaceState
    func moveWindow(_ windowID: CGWindowID, toWorkspace workspace: String)
    func focusWindow(_ windowID: CGWindowID)
    func switchToWorkspace(_ workspace: String)
}

/// Talks to AeroSpace through its CLI. Each CLI run takes ~20 ms (a state
/// fetch runs it three times); callers keep it
/// off the main thread where it runs often.
final class AeroSpaceClient: AeroSpaceControlling {
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

    var isAvailable: Bool { executableURL != nil }

    func fetchState() -> AeroSpaceState {
        guard let workspaceOutput = run([
            "list-workspaces", "--all", "--format", AeroSpaceOutputParser.workspaceListFormat
        ]),
        let windowOutput = run([
            "list-windows", "--all", "--format", AeroSpaceOutputParser.windowListFormat
        ]) else {
            return .empty
        }

        // No focused window (e.g. empty workspace) makes the CLI fail; that is fine.
        let focusedOutput = run([
            "list-windows", "--focused", "--format", AeroSpaceOutputParser.focusedWindowFormat
        ])

        return AeroSpaceState(
            workspaces: AeroSpaceOutputParser.workspaces(from: workspaceOutput),
            windows: AeroSpaceOutputParser.windows(from: windowOutput),
            focusedWindowID: focusedOutput.flatMap(AeroSpaceOutputParser.focusedWindowID(from:))
        )
    }

    func moveWindow(_ windowID: CGWindowID, toWorkspace workspace: String) {
        _ = run(["move-node-to-workspace", "--window-id", String(windowID), workspace])
    }

    func focusWindow(_ windowID: CGWindowID) {
        _ = run(["focus", "--window-id", String(windowID)])
    }

    func switchToWorkspace(_ workspace: String) {
        _ = run(["workspace", workspace])
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
