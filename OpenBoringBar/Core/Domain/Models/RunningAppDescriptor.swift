import Foundation

/// The parts of a running app needed to match it against pins.
struct RunningAppDescriptor: Hashable {
    let bundleIdentifier: String?
    let bundleURL: URL?
    var processID: pid_t? = nil
    var name: String? = nil
}
