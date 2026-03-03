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
        editMenuItem.state = .on
        lockMenuItem.state = .off
    }

    @objc private func toggleEdit() {
        let entering = !frameManager.isEditing
        frameManager.isEditing = entering
        editMenuItem.state = entering ? .on : .off
        lockMenuItem.state = .off
    }

    @objc private func lockFrames() {
        frameManager.isEditing = false
        editMenuItem.state = .off
        lockMenuItem.state = .on
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
