import Foundation

struct LaunchableApplicationItem: Identifiable, Hashable {
    let bundleURL: URL
    let name: String
    var bundleIdentifier: String? = nil

    var id: String { bundleURL.path }
}
