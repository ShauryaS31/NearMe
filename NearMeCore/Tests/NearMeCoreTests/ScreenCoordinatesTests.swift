import CoreGraphics
import Foundation
import NearMeCore
import Testing

@Test func mainDisplay() {
    // Primary 1440 x 900 display: AX and AppKit frames are both (0, 0, 1440, 900).
    let appKitDisplayFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let result = ScreenCoordinates.appKitRect(
        fromAX: CGRect(x: 100, y: 50, width: 200, height: 40), mainScreenHeight: 900)

    #expect(result == CGRect(x: 100, y: 810, width: 200, height: 40))
    #expect(appKitDisplayFrame.contains(result))
    // A control flush with the primary display's bottom edge maps to AppKit y = 0.
    #expect(ScreenCoordinates.appKitRect(
        fromAX: CGRect(x: 0, y: 880, width: 50, height: 20), mainScreenHeight: 900).minY == 0)
}

@Test func secondDisplayAbove() {
    // Primary 1440 x 900: AX/AppKit (0, 0, 1440, 900). Second 1920 x 1080 above:
    // AX (0, -1080, 1920, 1080), AppKit (0, 900, 1920, 1080).
    let primaryAppKitDisplayFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let appKitDisplayFrame = CGRect(x: 0, y: 900, width: 1920, height: 1080)
    let result = ScreenCoordinates.appKitRect(
        fromAX: CGRect(x: 300, y: -1000, width: 200, height: 50), mainScreenHeight: 900)

    #expect(result == CGRect(x: 300, y: 1850, width: 200, height: 50))
    #expect(appKitDisplayFrame.contains(result))
    #expect(!primaryAppKitDisplayFrame.contains(result))
}

@Test func secondDisplayLeft() {
    // Primary 1440 x 900: AX/AppKit (0, 0, 1440, 900). Second 1920 x 1080 left,
    // bottoms aligned: AX (-1920, -180, 1920, 1080), AppKit (-1920, 0, 1920, 1080).
    let primaryAppKitDisplayFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let appKitDisplayFrame = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
    let result = ScreenCoordinates.appKitRect(
        fromAX: CGRect(x: -1800, y: 100, width: 200, height: 50), mainScreenHeight: 900)

    #expect(result == CGRect(x: -1800, y: 750, width: 200, height: 50))
    #expect(appKitDisplayFrame.contains(result))
    #expect(!primaryAppKitDisplayFrame.contains(result))
}
