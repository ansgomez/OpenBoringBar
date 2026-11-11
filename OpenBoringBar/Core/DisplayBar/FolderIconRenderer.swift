import AppKit

/// Draws a folder widget's icon: the custom icon (or Finder's icon) with an
/// optional badge in the bottom-right corner. Results are cached per
/// appearance-independent key; images are vector or large, so one size fits.
final class FolderIconRenderer {
    static let shared = FolderIconRenderer()

    /// Badge edge as a share of the icon edge.
    static let badgeScale: CGFloat = 0.5
    /// Badge center height as a share of the icon height (front panel middle).
    static let badgeCenterHeight: CGFloat = 0.42
    /// White outline around badges, in canvas points (64 pt canvas).
    static let outlineWidth: CGFloat = 1.6
    private static let canvasSize = NSSize(width: 64, height: 64)

    private let cache = NSCache<NSString, NSImage>()

    func icon(for folder: PeekFolder) -> NSImage {
        let key = [
            folder.path, folder.customIconPath ?? "", folder.badgeImagePath ?? "",
            folder.badgeSymbol ?? "", folder.badgeColor?.rawValue ?? ""
        ]
            .joined(separator: "|") as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let base = folder.customIconPath.flatMap(NSImage.init(contentsOfFile:))
            ?? NSWorkspace.shared.icon(forFile: folder.path)
        let badge = folder.badgeImagePath.flatMap(NSImage.init(contentsOfFile:))
            ?? folder.badgeSymbol.flatMap {
                Self.symbolBadge(named: $0, color: folder.badgeColor?.nsColor ?? .controlAccentColor)
            }

        let image: NSImage
        if let badge {
            image = Self.compose(base: base, badge: badge)
        } else {
            image = base
        }
        cache.setObject(image, forKey: key)
        return image
    }

    /// Badge centered on the folder's front panel (the lower ~3/4 of a
    /// Finder folder icon), with a white outline so any image reads on blue.
    private static func compose(base: NSImage, badge: NSImage) -> NSImage {
        let outline = tinted(badge, with: .white)
        return NSImage(size: canvasSize, flipped: false) { rect in
            base.draw(in: rect)
            let side = rect.width * badgeScale
            let center = NSPoint(x: rect.midX, y: rect.minY + rect.height * badgeCenterHeight)
            let badgeRect = aspectFit(
                badge.size,
                in: NSRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
            )
            for step in 0..<16 {
                let angle = CGFloat(step) / 16 * 2 * .pi
                outline.draw(in: badgeRect.offsetBy(dx: cos(angle) * outlineWidth, dy: sin(angle) * outlineWidth))
            }
            badge.draw(in: badgeRect)
            return true
        }
    }

    /// The image's shape filled with one color.
    private static func tinted(_ image: NSImage, with fill: NSColor) -> NSImage {
        NSImage(size: image.size, flipped: false) { rect in
            image.draw(in: rect)
            fill.set()
            rect.fill(using: .sourceAtop)
            return true
        }
    }

    /// Heavy symbol in `color`, no background; `compose` adds the outline.
    private static func symbolBadge(named name: String, color: NSColor) -> NSImage? {
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 40, weight: .black)) else {
            return nil
        }
        return tinted(symbol, with: color)
    }

    private static func aspectFit(_ size: NSSize, in rect: NSRect) -> NSRect {
        guard size.width > 0, size.height > 0 else {
            return rect
        }
        let scale = min(rect.width / size.width, rect.height / size.height)
        let fitted = NSSize(width: size.width * scale, height: size.height * scale)
        return NSRect(
            x: rect.midX - fitted.width / 2,
            y: rect.midY - fitted.height / 2,
            width: fitted.width,
            height: fitted.height
        )
    }
}
