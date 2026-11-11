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
        runningMatch(pin, resolvedURL: resolvedURL, among: runningApps) != nil
    }

    /// The running apps that match none of the pins, in the given order.
    /// Several instances of one app count once; apps without a bundle
    /// location are left out.
    static func unpinnedRunningApps(
        among runningApps: [RunningAppDescriptor],
        pins: [(pin: PinnedApp, resolvedURL: URL?)]
    ) -> [RunningAppDescriptor] {
        var seen = Set<String>()
        return runningApps.filter { running in
            guard let bundleURL = running.bundleURL,
                  !pins.contains(where: { isRunning($0.pin, resolvedURL: $0.resolvedURL, among: [running]) }) else {
                return false
            }
            return seen.insert(running.bundleIdentifier ?? bundleURL.standardizedFileURL.path).inserted
        }
    }

    /// The first running app that matches the pin (see `isRunning`).
    static func runningMatch(
        _ pin: PinnedApp,
        resolvedURL: URL?,
        among runningApps: [RunningAppDescriptor]
    ) -> RunningAppDescriptor? {
        if let identifier = pin.bundleIdentifier {
            return runningApps.first { $0.bundleIdentifier == identifier }
        }

        let candidateURLs = Set([pin.bundleURL, resolvedURL].compactMap { $0?.standardizedFileURL })
        return runningApps.first { running in
            guard let runningURL = running.bundleURL?.standardizedFileURL else {
                return false
            }
            return candidateURLs.contains(runningURL)
        }
    }
}
