import CoreGraphics

struct RunningAppItem: Identifiable, Hashable {
    let processID: pid_t
    let name: String
    let isFrontmost: Bool
    let notificationBadgeCount: Int

    var id: pid_t { processID }
}

struct DisplayState: Identifiable {
    let id: CGDirectDisplayID
    let frame: CGRect
    let apps: [RunningAppItem]
    /// Filled by `BarManager` after the display state is built.
    var displayUUID: String? = nil
    var isMainDisplay: Bool = false
    var canEditPins: Bool = true
    var pinnedApps: [PinnedAppItem] = []
}
