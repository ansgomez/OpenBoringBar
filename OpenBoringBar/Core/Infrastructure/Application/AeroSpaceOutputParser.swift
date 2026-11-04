import CoreGraphics

/// Parses `aerospace` CLI output produced with the formats below.
enum AeroSpaceOutputParser {
    /// Title goes last: it may contain the separator.
    static let windowListFormat =
        "%{window-id}|%{workspace}|%{app-pid}|%{app-bundle-id}|%{app-name}|%{window-layout}|%{window-title}"
    static let focusedWindowFormat = "%{window-id}"
    static let workspaceListFormat =
        "%{workspace}|%{monitor-appkit-nsscreen-screens-id}|%{workspace-is-visible}|%{workspace-is-focused}"

    static func windows(from output: String) -> [AeroSpaceWindow] {
        lines(of: output).compactMap { line in
            let parts = line.split(separator: "|", maxSplits: 6, omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 7,
                  let windowID = CGWindowID(parts[0]),
                  !parts[1].isEmpty else {
                return nil
            }
            return AeroSpaceWindow(
                id: windowID,
                workspace: parts[1],
                processID: pid_t(parts[2]),
                bundleIdentifier: parts[3].isEmpty ? nil : parts[3],
                appName: parts[4],
                layout: parts[5],
                title: parts[6]
            )
        }
    }

    static func workspaces(from output: String) -> [AeroSpaceWorkspace] {
        lines(of: output).compactMap { line in
            let parts = line.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 4, !parts[0].isEmpty else {
                return nil
            }
            return AeroSpaceWorkspace(
                name: parts[0],
                screenNumber: Int(parts[1]),
                isVisible: parts[2] == "true",
                isFocused: parts[3] == "true"
            )
        }
    }

    static func focusedWindowID(from output: String) -> CGWindowID? {
        lines(of: output).lazy
            .compactMap { CGWindowID($0.trimmingCharacters(in: .whitespaces)) }
            .first
    }

    private static func lines(of output: String) -> [Substring] {
        output.split(whereSeparator: \.isNewline)
    }
}
