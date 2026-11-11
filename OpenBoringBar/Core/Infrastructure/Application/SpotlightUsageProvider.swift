import CoreServices
import Foundation

/// Reads how often and when an app was last opened from Spotlight metadata
/// (`kMDItemUseCount`, `kMDItemLastUsedDate`). Slow for many apps; call off
/// the main thread.
enum SpotlightUsageProvider {
    /// Not declared in the SDK headers, but what `mdls` shows.
    private static let useCountAttribute = "kMDItemUseCount" as CFString

    static func seeds(for applications: [LaunchableApplicationItem]) -> [AppUsageSeed] {
        applications.compactMap { app in
            guard let identifier = app.bundleIdentifier,
                  let item = MDItemCreateWithURL(nil, app.bundleURL as CFURL),
                  let useCount = MDItemCopyAttribute(item, useCountAttribute) as? NSNumber,
                  let lastUsed = MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date else {
                return nil
            }
            return AppUsageSeed(bundleIdentifier: identifier, useCount: useCount.intValue, lastUsed: lastUsed)
        }
    }
}
