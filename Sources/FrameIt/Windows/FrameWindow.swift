import Cocoa

// MARK: - FrameWindow
// Each glass frame is its own small borderless NSPanel.
// This allows multi-monitor support and doesn't block other apps.

class FrameWindow: NSPanel {

    let frameId: UUID

    /// Desktop level — frames visible behind icons, passthrough clicks
    private static let desktopLevel = NSWindow.Level(
        rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1
    )
    /// Edit level — just above desktop icons so we can interact
    private static let editLevel = NSWindow.Level(
        rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1
    )

    var isEditMode = false {
        didSet { updateEditState() }
    }

    init(frame: FrameGroup) {
        self.frameId = frame.id

        super.init(
            contentRect: frame.rect.cgRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Transparent shell
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false

        // Sit just above the desktop wallpaper
        level = Self.desktopLevel

        // Appear on all Spaces and stay put
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        // No Dock/Mission Control presence
        isExcludedFromWindowsMenu = true
        hidesOnDeactivate = false

        // Default: passthrough (user clicks go to desktop/icons/apps)
        ignoresMouseEvents = true

        // Floating panel settings
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true

        // Accept mouse events without requiring app activation first
        acceptsMouseMovedEvents = true
    }

    override var canBecomeKey: Bool { isEditMode }
    override var canBecomeMain: Bool { false }

    // MARK: - Edit State

    private func updateEditState() {
        if isEditMode {
            level = Self.editLevel
            ignoresMouseEvents = false
            makeKeyAndOrderFront(nil)
        } else {
            level = Self.desktopLevel
            ignoresMouseEvents = true
            orderFront(nil)
        }
    }

    // MARK: - Reposition

    func applyRect(_ rect: CGRect) {
        setFrame(rect, display: true)
    }
}

// MARK: - FirstMouseView
// An NSView that accepts the first mouse click without requiring app activation.

class FirstMouseView: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}
