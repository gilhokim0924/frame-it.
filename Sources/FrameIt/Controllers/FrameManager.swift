import Cocoa

// MARK: - FrameManager
// Manages all FrameWindows. Each frame is its own small NSPanel.

class FrameManager: GlassFrameViewDelegate, FrameCreationOverlayDelegate {
    let store: FrameStore
    private var windows: [UUID: FrameWindow] = [:]
    private var glassViews: [UUID: GlassFrameView] = [:]
    private let creationOverlay = FrameCreationOverlay()

    var isEditing = false {
        didSet {
            for window in windows.values {
                window.isEditMode = isEditing
            }
            for view in glassViews.values {
                view.isEditMode = isEditing
            }
        }
    }

    init(store: FrameStore) {
        self.store = store
        loadFrames()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDoneEditing),
            name: .frameDoneEditing,
            object: nil
        )
    }

    private func loadFrames() {
        for group in store.frames {
            createWindow(for: group)
        }
    }

    func addNewFrame() {
        creationOverlay.delegate = self
        creationOverlay.show()
    }

    func overlayDidCreateFrame(rect: CGRect) {
        let snappedRect = DesktopGrid(screen: targetScreen(for: rect)).snapRect(rect)
        let group = FrameGroup(title: "Untitled", rect: snappedRect)
        store.add(group)
        createWindow(for: group)

        isEditing = true
        NotificationCenter.default.post(name: .frameEditModeChanged, object: nil)
    }

    func overlayDidCancel() {}

    @discardableResult
    private func createWindow(for group: FrameGroup) -> FrameWindow {
        let window = FrameWindow(frame: group)
        let glassView = GlassFrameView(frameGroup: group)
        glassView.delegate = self
        glassView.isEditMode = isEditing
        glassView.autoresizingMask = [.width, .height]
        window.contentView = glassView

        window.isEditMode = isEditing
        window.orderFront(nil)

        windows[group.id] = window
        glassViews[group.id] = glassView
        return window
    }

    func glassFrameDidUpdate(_ view: GlassFrameView) {
        windows[view.frameGroup.id]?.applyRect(view.frameGroup.rect.cgRect)
        store.update(view.frameGroup)
    }

    func glassFrameDidMove(_ view: GlassFrameView, to rect: CGRect) {
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
        glassViews.removeValue(forKey: id)
    }

    @objc private func handleDoneEditing() {
        isEditing = false
        NotificationCenter.default.post(name: .frameEditModeChanged, object: nil)
    }

    private func targetScreen(for rect: CGRect) -> NSScreen? {
        NSScreen.screens.max { lhs, rhs in
            intersectionArea(between: lhs.frame, and: rect) < intersectionArea(between: rhs.frame, and: rect)
        }
    }

    private func intersectionArea(between lhs: CGRect, and rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull else { return 0 }
        return intersection.width * intersection.height
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let frameEditModeChanged = Notification.Name("frameEditModeChanged")
}
