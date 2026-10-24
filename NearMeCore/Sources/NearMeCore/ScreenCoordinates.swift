import CoreGraphics
import Foundation

public enum ScreenCoordinates {
    /// Converts AX coordinates using the primary display's height, regardless of the target display.
    public static func appKitRect(fromAX rect: CGRect, mainScreenHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: mainScreenHeight - rect.maxY, width: rect.width, height: rect.height)
    }
}
