import Cocoa

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {

    private var frameManager: FrameManager!
    private var menuBarController: MenuBarController!
    private let store = FrameStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Frame manager creates individual windows per frame
        frameManager = FrameManager(store: store)

        // Menu bar
        menuBarController = MenuBarController(frameManager: frameManager)
    }
}
