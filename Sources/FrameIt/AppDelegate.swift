import Cocoa

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {

    private var overlayWindow: DesktopOverlayWindow!
    private var overlayView: DesktopOverlayView!
    private var menuBarController: MenuBarController!
    private let store = FrameStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create overlay window
        overlayWindow = DesktopOverlayWindow()

        // Create overlay view
        overlayView = DesktopOverlayView(frame: overlayWindow.frame)
        overlayView.autoresizingMask = [.width, .height]
        overlayView.store = store
        overlayWindow.contentView = overlayView

        // Load persisted frames
        overlayView.reloadFrames()

        // Show the window
        overlayWindow.orderFront(nil)

        // Menu bar
        menuBarController = MenuBarController(overlayWindow: overlayWindow, overlayView: overlayView)

        // Listen for screen changes
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.overlayWindow.updateToScreen()
        }
    }
}
