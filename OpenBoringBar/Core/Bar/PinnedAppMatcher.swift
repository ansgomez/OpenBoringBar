import Foundation

/// Rules for deciding whether two apps are the same pinned app.
enum PinnedAppMatcher {
    /// Same bundle identifier when both have one; otherwise same location.
    /// Copies of one app that share an identifier count as one pin.
    static func isSameApp(_ lhs: PinnedApp, _ rhs: PinnedApp) -> Bool {
        if let lhsIdentifier = lhs.bundleIdentifier, let rhsIdentifier = rhs.bundleIdentifier {
            return lhsIdentifier == rhsIdentifier
        }
        return lhs.bundleURL.standardizedFileURL == rhs.bundleURL.standardizedFileURL
    }

    /// True when any running app matches the pin by identifier, or, for pins
    /// without one, by location (saved or resolved).
    static func isRunning(
        _ pin: PinnedApp,
        resolvedURL: URL?,
        among runningApps: [RunningAppDescriptor]
    ) -> Bool {
        if let identifier = pin.bundleIdentifier {
            return runningApps.contains { $0.bundleIdentifier == identifier }
        }

        let candidateURLs = Set([pin.bundleURL, resolvedURL].compactMap { $0?.standardizedFileURL })
        return runningApps.contains { running in
            guard let runningURL = running.bundleURL?.standardizedFileURL else {
                return false
            }
            return candidateURLs.contains(runningURL)
        }
    }
}
