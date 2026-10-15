import XCTest

final class ThumbnailPlaceholderTests: XCTestCase {
    private func solidImage(width: Int, height: Int, r: UInt8, g: UInt8, b: UInt8, a: UInt8) -> CGImage {
        let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255,
                                 alpha: CGFloat(a) / 255))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()!
    }

    func testVisuallyEmptyTransparentImage() {
        let image = solidImage(width: 64, height: 40, r: 0, g: 0, b: 0, a: 0)
        XCTAssertTrue(ThumbnailPlaceholder.isVisuallyEmpty(image))
    }

    func testVisuallyEmptySolidBlackImage() {
        let image = solidImage(width: 64, height: 40, r: 0, g: 0, b: 0, a: 255)
        XCTAssertTrue(ThumbnailPlaceholder.isVisuallyEmpty(image))
    }

    func testVisuallyEmptyRejectsDetailedDarkImage() {
        let ctx = CGContext(
            data: nil, width: 64, height: 40, bitsPerComponent: 8, bytesPerRow: 64 * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(gray: 0.08, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 64, height: 40))
        ctx.setFillColor(CGColor(gray: 0.55, alpha: 1))
        ctx.fill(CGRect(x: 20, y: 10, width: 24, height: 20))
        let image = ctx.makeImage()!
        XCTAssertFalse(ThumbnailPlaceholder.isVisuallyEmpty(image))
    }

    func testComposeCentersIconAndKeepsPixelSize() {
        let icon = solidImage(width: 128, height: 128, r: 40, g: 120, b: 200, a: 255)
        let composed = ThumbnailPlaceholder.compose(icon: icon, pointSize: CGSize(width: 200, height: 120), scale: 2)
        XCTAssertNotNil(composed)
        XCTAssertEqual(composed!.width, 400)
        XCTAssertEqual(composed!.height, 240)
        XCTAssertFalse(ThumbnailPlaceholder.isVisuallyEmpty(composed!))
    }
}
