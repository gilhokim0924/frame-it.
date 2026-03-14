import Cocoa

// MARK: - MenuBarController
// NSStatusItem-based menu bar interface for the app.

class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private let frameManager: FrameManager

    private var newFrameMenuItem: NSMenuItem!
    private var editMenuItem: NSMenuItem!

    init(frameManager: FrameManager) {
        self.frameManager = frameManager
        super.init()
        setupStatusItem()

        // Listen for edit mode changes from ✓ button or new frame creation
        NotificationCenter.default.addObserver(
            self, selector: #selector(editModeChanged),
            name: .frameEditModeChanged, object: nil
        )
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = makeStatusBarImage()
        }

        let menu = NSMenu()

        newFrameMenuItem = NSMenuItem(title: "New Frame", action: #selector(newFrame), keyEquivalent: "n")
        newFrameMenuItem.target = self
        menu.addItem(newFrameMenuItem)

        editMenuItem = NSMenuItem(title: "Edit Frames", action: #selector(toggleEdit), keyEquivalent: "e")
        editMenuItem.target = self
        menu.addItem(editMenuItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit frame it.", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        syncMenuState()
    }

    private func makeStatusBarImage() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        let outerRect = NSRect(x: 2.5, y: 2.5, width: 13, height: 13)
        let innerRect = NSRect(x: 5.5, y: 5.5, width: 7, height: 7)

        NSColor.black.setStroke()

        let outerPath = NSBezierPath(roundedRect: outerRect, xRadius: 3.5, yRadius: 3.5)
        outerPath.lineWidth = 1.6
        outerPath.stroke()

        let innerPath = NSBezierPath(roundedRect: innerRect, xRadius: 1.75, yRadius: 1.75)
        innerPath.lineWidth = 1.2
        innerPath.stroke()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    // MARK: - Actions

    @objc private func newFrame() {
        frameManager.addNewFrame()
        syncMenuState()
    }

    @objc private func toggleEdit() {
        frameManager.isEditing = !frameManager.isEditing
        syncMenuState()
    }

    @objc private func editModeChanged() {
        syncMenuState()
    }

    private func syncMenuState() {
        editMenuItem.state = frameManager.isEditing ? .on : .off
        editMenuItem.title = frameManager.isEditing ? "Done Editing" : "Edit Frames"
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
