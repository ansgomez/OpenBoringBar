import AppKit
import SwiftUI

/// Makes a view draggable as an AeroSpace window (payload: the window ID as
/// text, see `WorkspaceDragPayload`). Workspace groups in the workspace row
/// accept the drop. Does nothing when `windowID` is `nil`.
struct WindowDragSourceModifier: ViewModifier {
    let windowID: CGWindowID?
    let previewIcon: NSImage

    func body(content: Content) -> some View {
        if let windowID {
            content.draggable(String(windowID)) {
                Image(nsImage: previewIcon)
                    .resizable()
                    .frame(width: 24, height: 24)
            }
        } else {
            content
        }
    }
}

extension View {
    func windowDragSource(windowID: CGWindowID?, previewIcon: NSImage) -> some View {
        modifier(WindowDragSourceModifier(windowID: windowID, previewIcon: previewIcon))
    }
}
