import ApplicationServices
import CoreGraphics
import Foundation

/// Private but long-stable HIServices call (used by AeroSpace, yabai and
/// others) that returns the CoreGraphics window number of an AX window.
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

enum AXAttributeName {
    static let focusedWindow = "AXFocusedWindow" as CFString
    static let windows = "AXWindows" as CFString
    static let children = "AXChildren" as CFString
    static let title = "AXTitle" as CFString
    static let subrole = "AXSubrole" as CFString
    static let statusLabel = "AXStatusLabel" as CFString
    static let url = "AXURL" as CFString
    static let position = "AXPosition" as CFString
    static let size = "AXSize" as CFString
    static let minimized = "AXMinimized" as CFString
    static let fullScreen = "AXFullScreen" as CFString
    static let menuBar = "AXMenuBar" as CFString
    static let enabled = "AXEnabled" as CFString
    static let menuItemCommandCharacter = "AXMenuItemCmdChar" as CFString
    static let menuItemCommandModifiers = "AXMenuItemCmdModifiers" as CFString
}

enum AXNotificationName {
    static let focusedWindowChanged = "AXFocusedWindowChanged"
    static let mainWindowChanged = "AXMainWindowChanged"
    static let windowCreated = "AXWindowCreated"
    static let windowMiniaturized = "AXWindowMiniaturized"
    static let windowDeminiaturized = "AXWindowDeminiaturized"
    static let moved = "AXMoved"
    static let resized = "AXResized"
    static let titleChanged = "AXTitleChanged"
    static let childrenChanged = "AXChildrenChanged"
    static let selectedChildrenChanged = "AXSelectedChildrenChanged"
    static let layoutChanged = "AXLayoutChanged"
    static let created = "AXCreated"
    static let valueChanged = "AXValueChanged"
    static let applicationHidden = "AXApplicationHidden"
    static let applicationShown = "AXApplicationShown"
    static let uiElementDestroyed = "AXUIElementDestroyed"
}

enum AXElementInspector {
    static func focusedWindow(from appElement: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            AXAttributeName.focusedWindow,
            &value
        )

        guard result == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }

        return unsafeBitCast(value, to: AXUIElement.self)
    }

    static func windows(from appElement: AXUIElement) -> [AXUIElement]? {
        uiElementArrayAttributeValue(of: AXAttributeName.windows, from: appElement)
    }

    static func children(from element: AXUIElement) -> [AXUIElement]? {
        uiElementArrayAttributeValue(of: AXAttributeName.children, from: element)
    }

    static func frame(of window: AXUIElement) -> CGRect? {
        guard let position = pointAttributeValue(of: AXAttributeName.position, from: window),
              let size = sizeAttributeValue(of: AXAttributeName.size, from: window) else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }

    static func isWindowMinimized(_ window: AXUIElement) -> Bool {
        boolAttributeValue(of: AXAttributeName.minimized, from: window) ?? false
    }

    /// CoreGraphics window number of an AX window (same as AeroSpace's
    /// window ID), or `nil` if the system does not report one.
    static func windowID(of window: AXUIElement) -> CGWindowID? {
        var windowID: CGWindowID = 0
        guard _AXUIElementGetWindow(window, &windowID) == .success, windowID != 0 else {
            return nil
        }
        return windowID
    }

    static func isWindowFullScreen(_ window: AXUIElement) -> Bool {
        boolAttributeValue(of: AXAttributeName.fullScreen, from: window) ?? false
    }

    static func stringAttributeValue(of attribute: CFString, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            attribute,
            &value
        )

        guard result == .success,
              let string = value as? String else {
            return nil
        }

        return string
    }

    static func urlAttributeValue(of attribute: CFString, from element: AXUIElement) -> URL? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)

        guard result == .success else {
            return nil
        }

        if let url = value as? URL {
            return url
        }

        if let path = value as? String {
            if path.hasPrefix("file://") {
                return URL(string: path)
            }
            return URL(fileURLWithPath: path)
        }

        return nil
    }

    static func boolAttributeValue(of attribute: CFString, from element: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)

        guard result == .success,
              let number = value as? NSNumber else {
            return nil
        }

        return number.boolValue
    }

    static func intAttributeValue(of attribute: CFString, from element: AXUIElement) -> Int? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)

        guard result == .success,
              let number = value as? NSNumber else {
            return nil
        }

        return number.intValue
    }

    static func elementAttributeValue(of attribute: CFString, from element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)

        guard result == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }

        return unsafeBitCast(value, to: AXUIElement.self)
    }

    static func pointAttributeValue(of attribute: CFString, from element: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)

        guard result == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }

        let axValue = unsafeBitCast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cgPoint else {
            return nil
        }

        var point = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &point) else {
            return nil
        }

        return point
    }

    static func sizeAttributeValue(of attribute: CFString, from element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)

        guard result == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }

        let axValue = unsafeBitCast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cgSize else {
            return nil
        }

        var size = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &size) else {
            return nil
        }

        return size
    }

    private static func uiElementArrayAttributeValue(
        of attribute: CFString,
        from element: AXUIElement
    ) -> [AXUIElement]? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            attribute,
            &value
        )

        guard result == .success,
              let value,
              CFGetTypeID(value) == CFArrayGetTypeID() else {
            return nil
        }

        let array = unsafeBitCast(value, to: NSArray.self)
        return array.compactMap { item in
            guard CFGetTypeID(item as CFTypeRef) == AXUIElementGetTypeID() else {
                return nil
            }

            return unsafeBitCast(item as CFTypeRef, to: AXUIElement.self)
        }
    }
}
