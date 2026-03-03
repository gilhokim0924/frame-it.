import Cocoa

// MARK: - DesktopOverlayWindow
// A transparent, borderless window that sits just above the desktop wallpaper.

class DesktopOverlayWindow: NSWindow {

    /// Desktop level — frames visible behind icons, passthrough clicks
    private static let desktopLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
    /// Edit level — overlay above everything to receive mouse events
    private static let editLevel = NSWindow.Level.floating

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

        // Start at desktop level
        level = Self.desktopLevel

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

    // MARK: - Level Switching

    /// Raise to floating level so overlay receives mouse events for drawing/editing
    func enterEditLevel() {
        ignoresMouseEvents = false
        level = Self.editLevel
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Lower back to desktop level so icons sit above, clicks pass through
    func enterDesktopLevel() {
        ignoresMouseEvents = true
        level = Self.desktopLevel
        orderFront(nil)
    }

    // MARK: - Screen Change Handling

    func updateToScreen() {
        guard let screen = NSScreen.main else { return }
        setFrame(screen.frame, display: true)
    }
}
