import Cocoa

// MARK: - MenuBarController
// NSStatusItem-based menu bar interface for the app.

class MenuBarController: NSObject {

    private var statusItem: NSStatusItem!
    private let overlayWindow: DesktopOverlayWindow
    private let overlayView: DesktopOverlayView

    private var newFrameMenuItem: NSMenuItem!
    private var editMenuItem: NSMenuItem!
    private var lockMenuItem: NSMenuItem!

    init(overlayWindow: DesktopOverlayWindow, overlayView: DesktopOverlayView) {
        self.overlayWindow = overlayWindow
        self.overlayView = overlayView
        super.init()
        setupStatusItem()

        NotificationCenter.default.addObserver(
            self, selector: #selector(drawingEnded),
            name: .frameDrawingEnded, object: nil
        )
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            // Use SF Symbol for the icon
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
        // Enter draw mode — raise window to floating so it receives clicks
        overlayView.isEditing = true
        overlayView.isDrawing = true
        overlayWindow.enterEditLevel()
        newFrameMenuItem.state = .on

        // Change cursor to crosshair
        NSCursor.crosshair.push()
    }

    @objc private func toggleEdit() {
        let entering = !overlayView.isEditing

        overlayView.isEditing = entering

        if entering {
            overlayWindow.enterEditLevel()
        } else {
            overlayWindow.enterDesktopLevel()
        }

        editMenuItem.state = entering ? .on : .off
        lockMenuItem.state = .off
    }

    @objc private func lockFrames() {
        overlayView.isEditing = false
        overlayWindow.enterDesktopLevel()
        editMenuItem.state = .off
        lockMenuItem.state = .on
        NSCursor.pop()
    }

    @objc private func drawingEnded() {
        newFrameMenuItem.state = .off
        // Stay in edit mode so user can adjust the frame they just drew
        NSCursor.pop()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
