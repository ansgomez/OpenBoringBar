import CoreGraphics

/// Parses output of `aerospace list-windows --all --format '%{window-id}|%{workspace}'`.
enum AeroSpaceOutputParser {
    static let windowListFormat = "%{window-id}|%{workspace}"

    static func workspaceByWindowID(from output: String) -> [CGWindowID: String] {
        var result: [CGWindowID: String] = [:]
        for line in output.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2,
                  let windowID = CGWindowID(parts[0].trimmingCharacters(in: .whitespaces)) else {
                continue
            }
            let workspace = parts[1].trimmingCharacters(in: .whitespaces)
            if !workspace.isEmpty {
                result[windowID] = workspace
            }
        }
        return result
    }
}
