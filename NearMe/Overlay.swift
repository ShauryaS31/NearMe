import AppKit
import NearMeCore

@MainActor
private final class RingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
private final class RingView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.systemOrange.setStroke()
        let ring = NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 4), xRadius: 10, yRadius: 10)
        ring.lineWidth = 4
        ring.stroke()
    }
}

@MainActor
final class Overlay {
    private var panel: RingPanel?

    func show(axFrame: CGRect) {
        // screens.first is the primary/menu-bar screen defining AX's global origin.
        // NSScreen.main may instead be the screen containing NearMe's key window.
        guard let mainScreen = NSScreen.screens.first,
              axFrame.origin.x.isFinite, axFrame.origin.y.isFinite,
              axFrame.width.isFinite, axFrame.height.isFinite,
              axFrame.width > 0, axFrame.height > 0 else { clear(); return }
        let converted = ScreenCoordinates.appKitRect(fromAX: axFrame, mainScreenHeight: mainScreen.frame.height)
        let frame = converted.insetBy(dx: -6, dy: -6)
        let window: RingPanel
        if let panel {
            window = panel
        } else {
            window = RingPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                               backing: .buffered, defer: false)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.level = .screenSaver
            window.hidesOnDeactivate = false
            window.isFloatingPanel = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            window.contentView = RingView(frame: CGRect(origin: .zero, size: frame.size))
            panel = window
        }
        window.setFrame(frame, display: true)
        window.contentView?.needsDisplay = true
        window.orderFrontRegardless()
    }

    func clear() {
        panel?.orderOut(nil)
    }
}
