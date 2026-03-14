import Cocoa

// MARK: - FrameCreationOverlay

protocol FrameCreationOverlayDelegate: AnyObject {
    func overlayDidCreateFrame(rect: CGRect)
    func overlayDidCancel()
}

class FrameCreationOverlay {
    weak var delegate: FrameCreationOverlayDelegate?

    private var overlayWindows: [NSWindow] = []
    private var isCompleting = false

    func show() {
        hide()
        isCompleting = false

        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        for (index, screen) in screens.enumerated() {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = NSColor.black.withAlphaComponent(0.15)
            window.hasShadow = false
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 2)
            window.collectionBehavior = [.canJoinAllSpaces, .stationary]
            window.ignoresMouseEvents = false
            window.acceptsMouseMovedEvents = true

            let view = FrameDrawingView(frame: screen.frame)
            view.onComplete = { [weak self] rect in
                self?.complete(with: rect)
            }
            view.onCancel = { [weak self] in
                self?.cancel()
            }

            window.contentView = view

            if index == 0 {
                window.makeKeyAndOrderFront(nil)
            } else {
                window.orderFront(nil)
            }

            overlayWindows.append(window)
        }

        NSCursor.crosshair.push()
    }

    func hide() {
        guard !overlayWindows.isEmpty else { return }

        NSCursor.pop()
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
    }

    private func complete(with rect: CGRect) {
        guard !isCompleting else { return }
        isCompleting = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.hide()
            if rect.width > 30 && rect.height > 30 {
                self.delegate?.overlayDidCreateFrame(rect: rect)
            } else {
                self.delegate?.overlayDidCancel()
            }
        }
    }

    private func cancel() {
        guard !isCompleting else { return }
        isCompleting = true

        DispatchQueue.main.async { [weak self] in
            self?.hide()
            self?.delegate?.overlayDidCancel()
        }
    }
}

// MARK: - FrameDrawingView

class FrameDrawingView: NSView {
    var onComplete: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var startPoint: CGPoint?
    private var currentRect: CGRect?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentRect = nil
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }

        let current = convert(event.locationInWindow, from: nil)
        currentRect = CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let rect = currentRect, let window = window else {
            onCancel?()
            return
        }

        onComplete?(window.convertToScreen(rect))
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let rect = currentRect else { return }

        let path = NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12)
        NSColor.white.withAlphaComponent(0.1).setFill()
        path.fill()

        NSColor.white.withAlphaComponent(0.8).setStroke()
        path.lineWidth = 2
        path.setLineDash([6, 4], count: 2, phase: 0)
        path.stroke()
    }
}
