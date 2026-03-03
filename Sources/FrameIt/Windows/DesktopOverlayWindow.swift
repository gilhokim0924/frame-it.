import Cocoa

// MARK: - DesktopOverlayWindow
// A transparent, borderless window that sits just above the desktop wallpaper.

class DesktopOverlayWindow: NSWindow {

    init() {
        // Span the full main screen
        let screenFrame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)

        super.init(
            contentRect: screenFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        // Transparent background
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false

        // Sit just above the desktop wallpaper but below desktop icons
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)

        // Appear on all Spaces and stay fixed
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        // Don't show in Mission Control / Exposé
        isExcludedFromWindowsMenu = true

        // Start by ignoring mouse events (passthrough)
        ignoresMouseEvents = true

        // Keep the window from being hidden when the app is deactivated
        hidesOnDeactivate = false
    }

    // Allow the window to become key when we enable editing
    override var canBecomeKey: Bool { !ignoresMouseEvents }
    override var canBecomeMain: Bool { false }

    // MARK: - Screen Change Handling

    func updateToScreen() {
        guard let screen = NSScreen.main else { return }
        setFrame(screen.frame, display: true)
    }
}
