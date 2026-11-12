import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Draws the documentation images (`docs/screenshots`) from made-up data:
/// invented windows, titles, folders and system values, and only apps that
/// ship with macOS. Nothing is read from the real screen, AeroSpace or the
/// user's settings, so the images cannot leak private information.
///
/// Run: `OpenBoringBar --render-screenshots <folder>` (see
/// `scripts/render-screenshots.sh`). The real bar views are hosted in an
/// offscreen window and drawn into bitmaps.
enum ScreenshotRenderer {
    private static let argument = "--render-screenshots"
    private static let scale: CGFloat = 2
    private static let barHeight = BarLayoutConstants.panelHeight

    static func outputFolder(fromArguments arguments: [String]) -> URL? {
        guard let index = arguments.firstIndex(of: argument), index + 1 < arguments.count else {
            return nil
        }
        return URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
    }

    /// `false` when an image could not be written.
    static func renderAll(to folder: URL) -> Bool {
        _ = NSApplication.shared
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let environment = Environment()
        var succeeded = true

        func save(_ name: String, _ image: CGImage?) {
            guard let image, writePNG(image, to: folder.appendingPathComponent(name)) else {
                NSLog("OpenBoringBar: could not render \(name)")
                succeeded = false
                return
            }
        }

        let desktopSize = CGSize(width: 1440, height: 720)
        let stripSize = CGSize(width: 1440, height: 132)
        let base = Scene.base

        save("desktop.png", render(DesktopView(scene: base, environment: environment), size: desktopSize))

        let strip = render(StripView(scene: base, environment: environment), size: stripSize)
        save("bar.png", strip)
        save("bar-pins.png", strip.flatMap { crop($0, x: 0, width: 410, of: stripSize) })
        save("bar-workspaces.png", strip.flatMap { crop($0, x: 410, width: 745, of: stripSize) })
        save(
            "bar-unfolded.png",
            render(StripView(scene: base.unfolded(), environment: environment), size: stripSize)
        )

        let castSize = CGSize(width: 1200, height: 110)
        let frames = Scene.cast.compactMap {
            render(StripView(scene: $0, environment: environment), size: castSize, scale: 1)
        }
        if frames.count != Scene.cast.count
            || !writeGIF(frames, frameDuration: 1.4, to: folder.appendingPathComponent("bar-cast.gif")) {
            NSLog("OpenBoringBar: could not render bar-cast.gif")
            succeeded = false
        }
        return succeeded
    }

    // MARK: Rendering

    private static func render<Content: View>(
        _ content: Content,
        size: CGSize,
        scale: CGFloat = scale
    ) -> CGImage? {
        let frame = CGRect(origin: .zero, size: size)
        let hostingView = NSHostingView(rootView: content.frame(width: size.width, height: size.height))
        hostingView.frame = frame
        let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()
        // Lets the views settle: the stats sample and scroll views arrive
        // one run-loop turn later.
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        hostingView.layoutSubtreeIfNeeded()

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width * scale),
            pixelsHigh: Int(size.height * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }
        bitmap.size = size
        hostingView.cacheDisplay(in: frame, to: bitmap)
        return bitmap.cgImage
    }

    /// Crops a horizontal slice, given in points of the rendered size.
    private static func crop(_ image: CGImage, x: CGFloat, width: CGFloat, of size: CGSize) -> CGImage? {
        let factor = CGFloat(image.width) / size.width
        return image.cropping(to: CGRect(x: x * factor, y: 0, width: width * factor, height: CGFloat(image.height)))
    }

    private static func writePNG(_ image: CGImage, to url: URL) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil
        ) else {
            return false
        }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination)
    }

    private static func writeGIF(_ frames: [CGImage], frameDuration: Double, to url: URL) -> Bool {
        guard !frames.isEmpty, let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.gif.identifier as CFString, frames.count, nil
        ) else {
            return false
        }
        let gifKey = kCGImagePropertyGIFDictionary as String
        CGImageDestinationSetProperties(
            destination,
            [gifKey: [kCGImagePropertyGIFLoopCount as String: 0]] as CFDictionary
        )
        let frameProperties = [gifKey: [kCGImagePropertyGIFDelayTime as String: frameDuration]] as CFDictionary
        frames.forEach { CGImageDestinationAddImage(destination, $0, frameProperties) }
        return CGImageDestinationFinalize(destination)
    }
}

// MARK: - Made-up data

/// An app that ships with macOS, found by bundle identifier.
private struct DemoApp {
    let name: String
    let bundleIdentifier: String

    static let finder = DemoApp(name: "Finder", bundleIdentifier: "com.apple.finder")
    static let safari = DemoApp(name: "Safari", bundleIdentifier: "com.apple.Safari")
    static let mail = DemoApp(name: "Mail", bundleIdentifier: "com.apple.mail")
    static let calendar = DemoApp(name: "Calendar", bundleIdentifier: "com.apple.iCal")
    static let notes = DemoApp(name: "Notes", bundleIdentifier: "com.apple.Notes")
    static let music = DemoApp(name: "Music", bundleIdentifier: "com.apple.Music")
    static let maps = DemoApp(name: "Maps", bundleIdentifier: "com.apple.Maps")
    static let photos = DemoApp(name: "Photos", bundleIdentifier: "com.apple.Photos")
    static let reminders = DemoApp(name: "Reminders", bundleIdentifier: "com.apple.reminders")
    static let terminal = DemoApp(name: "Terminal", bundleIdentifier: "com.apple.Terminal")
    static let preview = DemoApp(name: "Preview", bundleIdentifier: "com.apple.Preview")
    static let textEdit = DemoApp(name: "TextEdit", bundleIdentifier: "com.apple.TextEdit")
    static let messages = DemoApp(name: "Messages", bundleIdentifier: "com.apple.MobileSMS")
    static let podcasts = DemoApp(name: "Podcasts", bundleIdentifier: "com.apple.podcasts")
    static let books = DemoApp(name: "Books", bundleIdentifier: "com.apple.iBooksX")
    static let weather = DemoApp(name: "Weather", bundleIdentifier: "com.apple.weather")
    static let clock = DemoApp(name: "Clock", bundleIdentifier: "com.apple.clock")

    var url: URL {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
            ?? URL(fileURLWithPath: "/System/Applications/\(name).app")
    }
}

private struct DemoWindow {
    let id: CGWindowID
    let app: DemoApp
    let title: String
    var isFloating = false
    var badgeCount = 0
}

/// One invented state of a desktop: its workspaces, windows and pins.
private struct Scene {
    var windowsByWorkspace: [String: [DemoWindow]]
    var visibleWorkspace: String
    var focusedWindowID: CGWindowID?
    var minimized: [DemoWindow]
    var showsPinStackUnfolded = false
    var showsPillsUnfolded = false

    private static let workspaceNames = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
    private static let pinned: [DemoApp] = [
        .finder, .safari, .maps, .mail, .photos, .calendar, .books, .notes, .weather, .music, .clock, .terminal
    ]
    private static let runningUnpinned: [DemoApp] = [.preview, .messages]

    static let base = Scene(
        windowsByWorkspace: [
            "1": [
                DemoWindow(id: 11, app: .safari, title: "Planning board"),
                DemoWindow(id: 12, app: .notes, title: "Meeting notes")
            ],
            "2": [
                DemoWindow(id: 21, app: .terminal, title: "demo — zsh"),
                DemoWindow(id: 22, app: .safari, title: "localhost:3000"),
                DemoWindow(id: 23, app: .messages, title: "Team chat", badgeCount: 2),
                DemoWindow(id: 24, app: .preview, title: "diagram.pdf", isFloating: true)
            ],
            "3": [DemoWindow(id: 31, app: .mail, title: "Inbox")],
            "4": [DemoWindow(id: 41, app: .music, title: "Music")],
            "6": [
                DemoWindow(id: 61, app: .calendar, title: "Calendar"),
                DemoWindow(id: 62, app: .reminders, title: "Reminders")
            ],
            "8": [DemoWindow(id: 81, app: .finder, title: "Documents")]
        ],
        visibleWorkspace: "2",
        focusedWindowID: 21,
        minimized: [DemoWindow(id: 91, app: .podcasts, title: "Podcasts")]
    )

    /// The animated tour: focus moves, workspaces change, a window is
    /// minimized, the stacks unfold.
    static var cast: [Scene] {
        var minimizedPreview = base
        minimizedPreview.windowsByWorkspace["2"]?.removeAll { $0.id == 24 }
        minimizedPreview.minimized.append(DemoWindow(id: 24, app: .preview, title: "diagram.pdf"))
        var pinsUnfolded = base
        pinsUnfolded.showsPinStackUnfolded = true
        var pillsUnfolded = base
        pillsUnfolded.showsPillsUnfolded = true
        return [
            base,
            pillsUnfolded,
            base.focusing(22),
            base.showing("1", focus: 11),
            base.showing("6", focus: 61),
            base,
            minimizedPreview,
            pinsUnfolded
        ]
    }

    func unfolded() -> Scene {
        var scene = self
        scene.showsPinStackUnfolded = true
        scene.showsPillsUnfolded = true
        return scene
    }

    func focusing(_ windowID: CGWindowID) -> Scene {
        var scene = self
        scene.focusedWindowID = windowID
        return scene
    }

    func showing(_ workspace: String, focus: CGWindowID) -> Scene {
        var scene = self
        scene.visibleWorkspace = workspace
        scene.focusedWindowID = focus
        return scene
    }

    // MARK: Bar models

    private var runningIdentifiers: Set<String> {
        Set(windowsByWorkspace.values.joined().map(\.app.bundleIdentifier))
            .union(minimized.map(\.app.bundleIdentifier))
    }

    private func pinItem(_ app: DemoApp, isPinned: Bool) -> PinnedAppItem {
        PinnedAppItem(
            pin: PinnedApp(bundleIdentifier: app.bundleIdentifier, bundleURL: app.url),
            resolvedURL: app.url,
            name: app.name,
            processID: runningIdentifiers.contains(app.bundleIdentifier) ? 1 : nil,
            isPinned: isPinned
        )
    }

    var pinnedApps: [PinnedAppItem] {
        Self.pinned.map { pinItem($0, isPinned: true) }
    }

    var runningUnpinnedApps: [PinnedAppItem] {
        Self.runningUnpinned
            .filter { runningIdentifiers.contains($0.bundleIdentifier) }
            .map { pinItem($0, isPinned: false) }
    }

    var workspaceGroups: [WorkspaceGroup] {
        Self.workspaceNames.map { name in
            WorkspaceGroup(
                name: name,
                isVisible: name == visibleWorkspace,
                isFocused: name == visibleWorkspace,
                windows: (windowsByWorkspace[name] ?? []).map { window in
                    AeroSpaceWindow(
                        id: window.id,
                        workspace: name,
                        processID: 1,
                        bundleIdentifier: window.app.bundleIdentifier,
                        appName: window.app.name,
                        layout: window.isFloating ? "floating" : "h_tiles",
                        title: window.title
                    )
                }
            )
        }
    }

    var pills: [RunningAppItem] {
        (windowsByWorkspace[visibleWorkspace] ?? []).map { window in
            RunningAppItem(
                processID: pid_t(window.id),
                name: window.title,
                isFrontmost: window.id == focusedWindowID,
                notificationBadgeCount: window.badgeCount,
                windowID: window.id,
                bundleIdentifier: window.app.bundleIdentifier
            )
        }
    }

    var minimizedWindows: [MinimizedWindow] {
        minimized.map { window in
            MinimizedWindow(
                id: window.id,
                processID: 1,
                appName: window.app.name,
                title: window.title,
                frame: .zero,
                bundleIdentifier: window.app.bundleIdentifier
            )
        }
    }
}

/// Fixed system values and folders, kept out of the user's settings.
private final class Environment {
    private final class FixedStats: SystemStatsProviding {
        func sample() -> SystemStats {
            SystemStats(
                cpuUsage: 0.23,
                memoryUsage: 0.61,
                diskUsage: 0.47,
                battery: BatteryStatus(level: 0.84, isCharging: false, isPluggedIn: false)
            )
        }
    }

    private final class NoStorage: PeekFolderStoring {
        func load() -> [PeekFolder]? { nil }
        func save(_ folders: [PeekFolder]) {}
    }

    let statsMonitor: SystemStatsMonitor
    let folderManager: FolderPeekManager

    init() {
        let suiteName = "OpenBoringBar.screenshots"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        statsMonitor = SystemStatsMonitor(provider: FixedStats(), defaults: defaults)
        folderManager = FolderPeekManager(storage: NoStorage(), defaults: defaults) {
            [
                PeekFolder(
                    path: "/Users/Shared", sortOrder: .name, keepsFoldersOnTop: true,
                    badgeSymbol: FolderBadgePreset.code.rawValue, badgeColor: .purple
                ),
                PeekFolder(
                    path: "/Library", sortOrder: .dateAdded, keepsFoldersOnTop: false,
                    badgeSymbol: FolderBadgePreset.download.rawValue, badgeColor: .green
                )
            ]
        }
    }
}

// MARK: - Views

private struct DemoBar: View {
    let scene: Scene
    let environment: Environment
    let width: CGFloat

    var body: some View {
        DisplayBottomBarView(
            apps: scene.pills,
            pinnedApps: scene.pinnedApps,
            runningUnpinnedApps: scene.runningUnpinnedApps,
            pinStripMaxWidth: width * BarLayoutConstants.pinStripMaxWidthFraction,
            pinDisplayMode: .allDisplays,
            launchableApplications: [],
            isAutoCollapseEnabled: false,
            hidesOffScreenWindows: true,
            isAeroSpaceAvailable: true,
            showsWorkspaces: true,
            pillsFollowWorkspace: true,
            showsEmptyWorkspaces: true,
            systemStatsMonitor: environment.statsMonitor,
            showsSystemStats: true,
            onShowsSystemStatsToggled: { _ in },
            folderPeekManager: environment.folderManager,
            showsFolders: true,
            onShowsFoldersToggled: { _ in },
            onOpenFolderMenu: { _ in },
            onAddFolder: {},
            onChooseImage: { _ in nil },
            workspaceGroups: scene.workspaceGroups,
            minimizedWindows: scene.minimizedWindows,
            onRestoreMinimizedWindow: { _ in },
            onMinimizeWindow: { _ in },
            emptyWorkspaceTarget: nil,
            onSwitchWorkspace: { _ in },
            onFocusWorkspaceWindow: { _ in },
            onMoveWindowToWorkspace: { _, _ in },
            onShowsWorkspacesToggled: { _ in },
            onPillsFollowWorkspaceToggled: { _ in },
            onShowsEmptyWorkspacesToggled: { _ in },
            onShowStartMenu: {},
            onOpenPinnedApp: { _ in },
            onShowPinMenu: { _, _, _, _ in },
            onPinDisplayModeChanged: { _ in },
            onSwitch: { _ in },
            onShowAppMenu: { _, _, _ in },
            onOpenApplication: { _ in },
            onAppHoverChanged: { _, _ in },
            onBarHoverChanged: { _ in },
            onAutoCollapseToggled: { _ in },
            onHidesOffScreenWindowsToggled: { _ in },
            onRequestQuit: {},
            showsPinStackUnfolded: scene.showsPinStackUnfolded,
            showsPillsUnfolded: scene.showsPillsUnfolded
        )
        .frame(width: width, height: BarLayoutConstants.panelHeight)
        // The bar's own material needs a live window behind it; offscreen,
        // a dark tint gives the same look.
        .background(Color.black.opacity(0.45))
    }
}

private struct Wallpaper: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.13, blue: 0.30),
                    Color(red: 0.32, green: 0.20, blue: 0.48),
                    Color(red: 0.86, green: 0.45, blue: 0.42)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color(red: 1.0, green: 0.78, blue: 0.50).opacity(0.55), .clear],
                center: UnitPoint(x: 0.82, y: 0.95),
                startRadius: 10,
                endRadius: 620
            )
        }
    }
}

/// The bar on a strip of wallpaper.
private struct StripView: View {
    let scene: Scene
    let environment: Environment

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Wallpaper()
                DemoBar(scene: scene, environment: environment, width: proxy.size.width)
            }
        }
    }
}

/// A whole invented desktop: two tiled windows above the bar.
private struct DesktopView: View {
    let scene: Scene
    let environment: Environment

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Wallpaper()
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        DemoTerminalWindow()
                        DemoBrowserWindow()
                    }
                    .padding(10)
                    DemoBar(scene: scene, environment: environment, width: proxy.size.width)
                }
            }
        }
    }
}

private struct DemoWindowChrome<Content: View>: View {
    let title: String
    let barColor: Color
    let titleColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                barColor
                HStack(spacing: 8) {
                    ForEach([Color.red, Color.yellow, Color.green], id: \.self) { color in
                        Circle().fill(color.opacity(0.9)).frame(width: 12, height: 12)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(titleColor)
            }
            .frame(height: 38)
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
    }
}

private struct DemoTerminalWindow: View {
    private static let lines: [(text: String, color: Color)] = [
        ("demo % ./scripts/bootstrap.sh", .white),
        ("==> pod install", Color(red: 0.55, green: 0.80, blue: 1.0)),
        ("==> build", Color(red: 0.55, green: 0.80, blue: 1.0)),
        ("** BUILD SUCCEEDED **", Color(red: 0.55, green: 0.90, blue: 0.60)),
        ("==> test", Color(red: 0.55, green: 0.80, blue: 1.0)),
        ("Executed 112 tests, with 0 failures", .white),
        ("** TEST SUCCEEDED **", Color(red: 0.55, green: 0.90, blue: 0.60)),
        ("demo % ./scripts/install.sh", .white),
        ("==> launched", Color(red: 0.55, green: 0.80, blue: 1.0)),
        ("demo % ▋", .white)
    ]

    var body: some View {
        DemoWindowChrome(
            title: "demo — zsh",
            barColor: Color(red: 0.16, green: 0.17, blue: 0.21),
            titleColor: Color.white.opacity(0.75)
        ) {
            VStack(alignment: .leading, spacing: 9) {
                ForEach(Array(Self.lines.enumerated()), id: \.offset) { _, line in
                    Text(line.text)
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundStyle(line.color.opacity(0.92))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(red: 0.09, green: 0.10, blue: 0.13))
        }
    }
}

private struct DemoBrowserWindow: View {
    var body: some View {
        DemoWindowChrome(
            title: "localhost:3000",
            barColor: Color(red: 0.93, green: 0.93, blue: 0.95),
            titleColor: Color.black.opacity(0.65)
        ) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Demo Dashboard")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.85))
                Text("Everything on this page is placeholder content.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.black.opacity(0.5))
                HStack(spacing: 14) {
                    card("Visitors", "1,024", Color(red: 0.30, green: 0.50, blue: 0.95))
                    card("Signups", "64", Color(red: 0.55, green: 0.35, blue: 0.90))
                    card("Uptime", "99.9%", Color(red: 0.20, green: 0.70, blue: 0.55))
                }
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.05))
                    .overlay(
                        HStack(alignment: .bottom, spacing: 14) {
                            ForEach(Array([0.35, 0.55, 0.42, 0.70, 0.62, 0.85, 0.74, 0.92].enumerated()), id: \.offset) { _, value in
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Color(red: 0.30, green: 0.50, blue: 0.95).opacity(0.75))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 190 * value)
                            }
                        }
                        .padding(22),
                        alignment: .bottom
                    )
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.white)
        }
    }

    private func card(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.85))
            Text(value)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(color))
    }
}
