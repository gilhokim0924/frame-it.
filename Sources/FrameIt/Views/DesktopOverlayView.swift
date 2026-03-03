import Cocoa

// MARK: - DesktopOverlayView
// Root view for the overlay window. Manages GlassFrameViews and handles the
// "draw a new frame" gesture.

class DesktopOverlayView: NSView, GlassFrameViewDelegate {

    var store: FrameStore!

    // Drawing state
    var isDrawing = false
    private var drawStart: NSPoint?
    private var drawRect: NSRect = .zero
    private let rubberBandLayer = CAShapeLayer()

    // Edit mode
    var isEditing = false {
        didSet {
            // When editing is disabled, turn off the drawing flag too
            if !isEditing { isDrawing = false }
        }
    }

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        // Rubber-band rectangle while drawing
        rubberBandLayer.fillColor = NSColor.white.withAlphaComponent(0.05).cgColor
        rubberBandLayer.strokeColor = NSColor.white.withAlphaComponent(0.3).cgColor
        rubberBandLayer.lineWidth = 1.5
        rubberBandLayer.lineDashPattern = [6, 3]
        rubberBandLayer.isHidden = true
        layer?.addSublayer(rubberBandLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Load Frames from Store

    func reloadFrames() {
        // Remove existing glass frame views
        subviews.compactMap { $0 as? GlassFrameView }.forEach { $0.removeFromSuperview() }

        for group in store.frames {
            let view = GlassFrameView(frameGroup: group)
            view.delegate = self
            addSubview(view)
        }
    }

    // MARK: - Mouse: Draw New Frame

    override func mouseDown(with event: NSEvent) {
        guard isDrawing else { return }
        drawStart = convert(event.locationInWindow, from: nil)
        rubberBandLayer.isHidden = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDrawing, let start = drawStart else { return }
        let current = convert(event.locationInWindow, from: nil)
        drawRect = NSRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
        rubberBandLayer.path = CGPath(roundedRect: drawRect, cornerWidth: 14, cornerHeight: 14, transform: nil)
    }

    override func mouseUp(with event: NSEvent) {
        guard isDrawing, drawStart != nil else { return }
        rubberBandLayer.isHidden = true
        drawStart = nil

        // Minimum size check
        guard drawRect.width >= 60 && drawRect.height >= 60 else { return }

        let newGroup = FrameGroup(rect: drawRect)
        store.add(newGroup)

        let view = GlassFrameView(frameGroup: newGroup)
        view.delegate = self
        addSubview(view)

        // Exit draw mode after creating a frame
        isDrawing = false

        // Notify delegate to update menu state
        NotificationCenter.default.post(name: .frameDrawingEnded, object: nil)
    }

    // MARK: - GlassFrameViewDelegate

    func glassFrameDidUpdate(_ view: GlassFrameView) {
        store.update(view.frameGroup)
    }

    func glassFrameDidRequestDelete(_ view: GlassFrameView) {
        store.remove(id: view.frameGroup.id)
        view.removeFromSuperview()
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let frameDrawingEnded = Notification.Name("frameDrawingEnded")
}
