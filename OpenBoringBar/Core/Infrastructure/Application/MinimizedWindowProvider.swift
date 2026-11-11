import AppKit
import ApplicationServices

/// Lists minimized windows of regular apps through the Accessibility API.
enum MinimizedWindowProvider {
    static func minimizedWindows() -> [MinimizedWindow] {
        guard AXIsProcessTrusted() else {
            return []
        }

        var result: [MinimizedWindow] = []
        for app in NSWorkspace.shared.runningApplications {
            guard !app.isTerminated, app.activationPolicy == .regular else {
                continue
            }
            let processID = app.processIdentifier
            let appElement = AXUIElementCreateApplication(processID)
            guard let windows = AXElementInspector.windows(from: appElement) else {
                continue
            }

            let appName = app.localizedName ?? "App"
            for window in windows where AXElementInspector.isWindowMinimized(window) {
                guard let windowID = AXElementInspector.windowID(of: window) else {
                    continue
                }
                let title = AXElementInspector.stringAttributeValue(
                    of: AXAttributeName.title,
                    from: window
                )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                result.append(MinimizedWindow(
                    id: windowID,
                    processID: processID,
                    appName: appName,
                    title: title,
                    frame: AXElementInspector.frame(of: window) ?? .zero
                ))
            }
        }
        return result
    }
}
