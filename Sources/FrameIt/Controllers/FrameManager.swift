import Cocoa

// MARK: - FrameManager
// Manages all FrameWindows. Replaces the old DesktopOverlayWindow/View approach.

class FrameManager: GlassFrameViewDelegate {

    let store: FrameStore
    private var windows: [UUID: FrameWindow] = [:]

    var isEditing = false {
        didSet {
            for (_, window) in windows {
                window.isEditMode = isEditing
            }
        }
    }

    init(store: FrameStore) {
        self.store = store
        loadFrames()
    }

    // MARK: - Load from Store

    private func loadFrames() {
        for group in store.frames {
            createWindow(for: group)
        }
    }

    // MARK: - Create / Remove

    func addNewFrame() {
        // Find the screen where the mouse currently is
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first!

        // Place a default 250×180 frame in the center of that screen
        let w: CGFloat = 250
        let h: CGFloat = 180
        let x = screen.frame.midX - w / 2
        let y = screen.frame.midY - h / 2

        let group = FrameGroup(title: "Untitled", rect: CGRect(x: x, y: y, width: w, height: h))
        store.add(group)
        createWindow(for: group)

        // Enter edit mode so user can immediately reposition/rename
        isEditing = true
    }

    @discardableResult
    private func createWindow(for group: FrameGroup) -> FrameWindow {
        let window = FrameWindow(frame: group)

        let glassView = GlassFrameView(frameGroup: group)
        glassView.delegate = self
        glassView.autoresizingMask = [.width, .height]
        window.contentView = glassView

        window.isEditMode = isEditing
        window.orderFront(nil)

        windows[group.id] = window
        return window
    }

    // MARK: - GlassFrameViewDelegate

    func glassFrameDidUpdate(_ view: GlassFrameView) {
        // Sync the window frame with the model
        if let window = windows[view.frameGroup.id] {
            window.applyRect(view.frameGroup.rect.cgRect)
        }
        store.update(view.frameGroup)
    }

    func glassFrameDidMove(_ view: GlassFrameView, to rect: CGRect) {
        // The user dragged the entire window — update model
        var group = view.frameGroup
        group.rect = CodableRect(cgRect: rect)
        view.frameGroup = group
        store.update(group)
    }

    func glassFrameDidRequestDelete(_ view: GlassFrameView) {
        let id = view.frameGroup.id
        store.remove(id: id)
        windows[id]?.close()
        windows.removeValue(forKey: id)
    }
}
