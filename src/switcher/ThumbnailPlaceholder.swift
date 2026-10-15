import Cocoa

/// Soft card drawn when a window has no usable screenshot (KeePassXC blocks capture, etc.).
/// Keeps the tile’s window aspect so the grid stays calm; centers the app icon instead of leaving
/// an empty letterboxed hole (#2884).
enum ThumbnailPlaceholder {
    /// Icon side as a fraction of the shorter thumbnail edge — large enough to read, not a full-bleed logo.
    static let iconFraction: CGFloat = 0.42

    /// Captures that are fully transparent or a flat near-black void (blocked / unavailable content).
    static func isVisuallyEmpty(_ contents: CALayerContents) -> Bool {
        guard case .cgImage(let image?) = contents else { return true }
        return isVisuallyEmpty(image)
    }

    static func isVisuallyEmpty(_ image: CGImage) -> Bool {
        let side = 8
        guard let ctx = CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return false }
        ctx.interpolationQuality = .low
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        guard let data = ctx.data else { return false }
        let ptr = data.bindMemory(to: UInt8.self, capacity: side * side * 4)
        var maxAlpha = 0
        var maxLum = 0
        var minLum = 255
        for i in 0..<(side * side) {
            let o = i * 4
            let r = Int(ptr[o]), g = Int(ptr[o + 1]), b = Int(ptr[o + 2]), a = Int(ptr[o + 3])
            maxAlpha = max(maxAlpha, a)
            let lum = (r + g + b) / 3
            maxLum = max(maxLum, lum)
            minLum = min(minLum, lum)
        }
        if maxAlpha < 10 { return true }
        // Solid black/near-black with no structure — typical of a blocked capture, not a dark UI.
        return maxLum < 14 && (maxLum - minLum) < 8
    }

    /// Window-shaped card with a centered app icon. `pointSize` matches the tile thumbnail; `scale` is the
    /// screen backing scale so the bitmap stays sharp.
    static func compose(icon: CGImage?, pointSize: CGSize, scale: CGFloat) -> CGImage? {
        guard pointSize.width >= 1, pointSize.height >= 1 else { return nil }
        let scale = max(1, scale)
        let pixelW = max(1, Int((pointSize.width * scale).rounded()))
        let pixelH = max(1, Int((pointSize.height * scale).rounded()))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: pixelW, height: pixelH, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.setFillColor(cardFillColor())
        let bounds = CGRect(x: 0, y: 0, width: pixelW, height: pixelH)
        let radius = CGFloat(min(pixelW, pixelH)) * 0.06
        ctx.addPath(CGPath(roundedRect: bounds, cornerWidth: radius, cornerHeight: radius, transform: nil))
        ctx.fillPath()
        if let icon {
            let side = CGFloat(min(pixelW, pixelH)) * iconFraction
            let iconRect = CGRect(
                x: (CGFloat(pixelW) - side) / 2,
                y: (CGFloat(pixelH) - side) / 2,
                width: side, height: side)
            ctx.interpolationQuality = .high
            ctx.draw(icon, in: iconRect)
        }
        return ctx.makeImage()
    }

    private static func cardFillColor() -> CGColor {
        // Prefer the running app's appearance; unit tests have no NSApp — use a mid gray that
        // reads on both light and dark tile backgrounds.
        if let app = NSApp {
            let dark = app.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return dark ? CGColor(gray: 1, alpha: 0.10) : CGColor(gray: 0, alpha: 0.07)
        }
        return CGColor(gray: 0.5, alpha: 0.12)
    }
}
