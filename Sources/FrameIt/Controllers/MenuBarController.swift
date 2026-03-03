import Cocoa

// MARK: - MenuBarController
// NSStatusItem-based menu bar interface for the app.

class MenuBarController: NSObject {

    private var statusItem: NSStatusItem!
    private let frameManager: FrameManager

    private var newFrameMenuItem: NSMenuItem!
    private var editMenuItem: NSMenuItem!
    private var lockMenuItem: NSMenuItem!

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
            if let image = NSImage(systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: "Frame It") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "⊞"
            }
        }

        let menu = NSMenu()

        newFrameMenuItem = NSMenuItem(title: "New Frame", action: #selector(newFrame), keyEquivalent: "n")
        newFrameMenuItem.target = self
        menu.addItem(newFrameMenuItem)

        editMenuItem = NSMenuItem(title: "Edit Frames", action: #selector(toggleEdit), keyEquivalent: "e")
        editMenuItem.target = self
        menu.addItem(editMenuItem)

        lockMenuItem = NSMenuItem(title: "Lock Frames", action: #selector(lockFrames), keyEquivalent: "l")
        lockMenuItem.target = self
        menu.addItem(lockMenuItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Frame It", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
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

    @objc private func lockFrames() {
        frameManager.isEditing = false
        syncMenuState()
    }

    @objc private func editModeChanged() {
        syncMenuState()
    }

    private func syncMenuState() {
        editMenuItem.state = frameManager.isEditing ? .on : .off
        lockMenuItem.state = frameManager.isEditing ? .off : .on
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
