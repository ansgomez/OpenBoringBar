import AppKit
import SwiftUI

@main
struct OpenBoringBarApp: App {
    @StateObject private var permissionManager = PermissionManager()
    @StateObject private var runtimeCoordinator = AppRuntimeCoordinator()

    private let setupMinHeight: CGFloat = 590
    private let runtimeMinHeight: CGFloat = 540
    private let width: CGFloat = 500

    var body: some Scene {
        WindowGroup {
            Group {
                if permissionManager.shouldPresentSetup {
                    PermissionSetupView()
                        .environmentObject(permissionManager)
                } else if runtimeCoordinator.barManager != nil {
                    PanelBootstrapView()
                        .task {
                            runtimeCoordinator.startPanelsIfNeeded()
                        }
                } else {
                    ProgressView("Starting boringBar...")
                        .task {
                            runtimeCoordinator.startBarManagerIfNeeded()
                        }
                }
            }
            .onAppear {
                Self.showInDock(permissionManager.shouldPresentSetup)
            }
            .onChange(of: permissionManager.shouldPresentSetup) { _, shouldPresent in
                Self.showInDock(shouldPresent)
                if shouldPresent {
                    runtimeCoordinator.stopPanelsAndReset()
                } else {
                    runtimeCoordinator.startBarManagerIfNeeded()
                }
            }
            .frame(width: width, height: permissionManager.shouldPresentSetup ? setupMinHeight : runtimeMinHeight)
        }
        .defaultSize(width: width, height: setupMinHeight)
        .windowResizability(.contentSize)
    }
}

extension OpenBoringBarApp {
    /// The app is a background agent (`LSUIElement`). While the permission
    /// setup window is shown it becomes a regular app and comes to the front,
    /// so the window can be found again behind System Settings (Dock icon,
    /// Command-Tab).
    fileprivate static func showInDock(_ isShown: Bool) {
        NSApp.setActivationPolicy(isShown ? .regular : .accessory)
        if isShown {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

private struct PanelBootstrapView: View {
    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityHidden(true)
    }
}
