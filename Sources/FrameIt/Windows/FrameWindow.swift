import Cocoa

// MARK: - FrameWindow
// Each glass frame is its own small borderless NSPanel.
// This allows multi-monitor support and doesn't block other apps.

class FrameWindow: NSPanel {

    let frameId: UUID
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
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)

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
    }

    override var canBecomeKey: Bool { isEditMode }
    override var canBecomeMain: Bool { false }

    // MARK: - Edit State

    private func updateEditState() {
        if isEditMode {
            // Raise above everything so we can interact with the frame
            level = .floating
            ignoresMouseEvents = false
        } else {
            // Lower back to desktop level, passthrough
            level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
            ignoresMouseEvents = true
        }
    }

    // MARK: - Reposition

    func applyRect(_ rect: CGRect) {
        setFrame(rect, display: true)
    }
}
