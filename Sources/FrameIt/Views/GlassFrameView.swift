import Cocoa

// MARK: - Accent Colors for Frames

struct FrameColors {
    static let palettes: [(border: NSColor, tint: NSColor, name: String)] = [
        (
            NSColor.white.withAlphaComponent(0.25),
            NSColor.white.withAlphaComponent(0.06),
            "Clear"
        ),
        (
            NSColor.systemBlue.withAlphaComponent(0.40),
            NSColor.systemBlue.withAlphaComponent(0.08),
            "Blue"
        ),
        (
            NSColor.systemPurple.withAlphaComponent(0.40),
            NSColor.systemPurple.withAlphaComponent(0.08),
            "Purple"
        ),
        (
            NSColor.systemPink.withAlphaComponent(0.40),
            NSColor.systemPink.withAlphaComponent(0.08),
            "Pink"
        ),
        (
            NSColor.systemOrange.withAlphaComponent(0.40),
            NSColor.systemOrange.withAlphaComponent(0.08),
            "Orange"
        ),
        (
            NSColor.systemGreen.withAlphaComponent(0.40),
            NSColor.systemGreen.withAlphaComponent(0.08),
            "Green"
        ),
        (
            NSColor.systemTeal.withAlphaComponent(0.40),
            NSColor.systemTeal.withAlphaComponent(0.08),
            "Teal"
        ),
    ]

    static func border(for index: Int) -> NSColor {
        palettes[index % palettes.count].border
    }

    static func tint(for index: Int) -> NSColor {
        palettes[index % palettes.count].tint
    }

    static func name(for index: Int) -> String {
        palettes[index % palettes.count].name
    }
}

// MARK: - GlassFrameView
// Content view for a FrameWindow. Renders the frosted-glass effect and
// handles drag-to-move (moves the parent window) and edge-resize.

class GlassFrameView: NSView {

    var frameGroup: FrameGroup {
        didSet { applyStyle() }
    }

    weak var delegate: GlassFrameViewDelegate?

    // Subviews
    private let effectView = NSVisualEffectView()
    private let tintOverlay = NSView()
    private let titleLabel = NSTextField()
    private let borderLayer = CAShapeLayer()

    // Interaction state
    private var initialMouseLocation: NSPoint = .zero
    private var initialWindowFrame: CGRect = .zero
    private var resizeEdge: ResizeEdge = .none

    private let handleSize: CGFloat = 8
    private let cornerRadius: CGFloat = 14

    // MARK: - Init

    init(frameGroup: FrameGroup) {
        self.frameGroup = frameGroup
        super.init(frame: NSRect(origin: .zero, size: frameGroup.rect.cgRect.size))
        setupViews()
        applyStyle()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupViews() {
        wantsLayer = true

        // Visual Effect (frosted glass)
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = cornerRadius
        effectView.layer?.masksToBounds = true
        effectView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(effectView)

        // Tint overlay for color accent
        tintOverlay.wantsLayer = true
        tintOverlay.layer?.cornerRadius = cornerRadius
        tintOverlay.layer?.masksToBounds = true
        tintOverlay.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tintOverlay)

        // Border
        borderLayer.fillColor = nil
        borderLayer.lineWidth = 1.0
        layer?.addSublayer(borderLayer)

        // Title label
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.isBezeled = false
        titleLabel.drawsBackground = false
        titleLabel.textColor = NSColor.white.withAlphaComponent(0.85)
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.alignment = .left
        titleLabel.cell?.truncatesLastVisibleLine = true
        titleLabel.cell?.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        // Constraints
        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor),

            tintOverlay.topAnchor.constraint(equalTo: topAnchor),
            tintOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            tintOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            tintOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),

            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            titleLabel.heightAnchor.constraint(equalToConstant: 18),
        ])
    }

    private func applyStyle() {
        let ci = frameGroup.colorIndex
        tintOverlay.layer?.backgroundColor = FrameColors.tint(for: ci).cgColor
        borderLayer.strokeColor = FrameColors.border(for: ci).cgColor
        titleLabel.stringValue = frameGroup.title
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let path = CGPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
                          cornerWidth: cornerRadius, cornerHeight: cornerRadius,
                          transform: nil)
        borderLayer.path = path
        borderLayer.frame = bounds
    }

    // MARK: - Mouse Handling (moves/resizes the parent WINDOW)

    override func mouseDown(with event: NSEvent) {
        // Double-click to rename
        if event.clickCount == 2 {
            renameAction()
            return
        }

        guard let window = window else { return }
        initialMouseLocation = NSEvent.mouseLocation
        initialWindowFrame = window.frame
        resizeEdge = detectEdge(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = window else { return }
        let currentMouse = NSEvent.mouseLocation
        let dx = currentMouse.x - initialMouseLocation.x
        let dy = currentMouse.y - initialMouseLocation.y

        if resizeEdge != .none {
            let newFrame = computeResize(dx: dx, dy: dy)
            window.setFrame(newFrame, display: true)
        } else {
            // Move the window
            var newOrigin = initialWindowFrame.origin
            newOrigin.x += dx
            newOrigin.y += dy
            window.setFrameOrigin(newOrigin)
        }
    }

    override func mouseUp(with event: NSEvent) {
        resizeEdge = .none
        guard let window = window else { return }

        // Persist the new window position/size
        let rect = window.frame
        delegate?.glassFrameDidMove(self, to: rect)
    }

    // MARK: - Context Menu

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()

        let renameItem = NSMenuItem(title: "Rename", action: #selector(renameAction), keyEquivalent: "")
        renameItem.target = self
        menu.addItem(renameItem)

        // Color submenu
        let colorMenu = NSMenu()
        for (i, palette) in FrameColors.palettes.enumerated() {
            let item = NSMenuItem(title: palette.name, action: #selector(changeColorAction(_:)), keyEquivalent: "")
            item.tag = i
            item.target = self
            if i == frameGroup.colorIndex { item.state = .on }
            colorMenu.addItem(item)
        }
        let colorItem = NSMenuItem(title: "Color", action: nil, keyEquivalent: "")
        colorItem.submenu = colorMenu
        menu.addItem(colorItem)

        menu.addItem(.separator())

        let deleteItem = NSMenuItem(title: "Delete", action: #selector(deleteAction), keyEquivalent: "")
        deleteItem.target = self
        menu.addItem(deleteItem)

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func renameAction() {
        titleLabel.isEditable = true
        titleLabel.isSelectable = true
        titleLabel.becomeFirstResponder()
        titleLabel.delegate = self
    }

    @objc private func changeColorAction(_ sender: NSMenuItem) {
        frameGroup.colorIndex = sender.tag
        applyStyle()
        delegate?.glassFrameDidUpdate(self)
    }

    @objc private func deleteAction() {
        delegate?.glassFrameDidRequestDelete(self)
    }

    // MARK: - Resize Edge Detection

    enum ResizeEdge {
        case none, top, bottom, left, right, topLeft, topRight, bottomLeft, bottomRight
    }

    private func detectEdge(at point: NSPoint) -> ResizeEdge {
        let h = handleSize
        let b = bounds

        let onLeft   = point.x < h
        let onRight  = point.x > b.width - h
        let onBottom = point.y < h
        let onTop    = point.y > b.height - h

        if onTop && onLeft { return .topLeft }
        if onTop && onRight { return .topRight }
        if onBottom && onLeft { return .bottomLeft }
        if onBottom && onRight { return .bottomRight }
        if onTop { return .top }
        if onBottom { return .bottom }
        if onLeft { return .left }
        if onRight { return .right }
        return .none
    }

    private func computeResize(dx: CGFloat, dy: CGFloat) -> CGRect {
        var r = initialWindowFrame
        let minSize: CGFloat = 80

        switch resizeEdge {
        case .right:
            r.size.width = max(minSize, initialWindowFrame.width + dx)
        case .left:
            r.origin.x = initialWindowFrame.origin.x + dx
            r.size.width = max(minSize, initialWindowFrame.width - dx)
        case .top:
            r.size.height = max(minSize, initialWindowFrame.height + dy)
        case .bottom:
            r.origin.y = initialWindowFrame.origin.y + dy
            r.size.height = max(minSize, initialWindowFrame.height - dy)
        case .topRight:
            r.size.width = max(minSize, initialWindowFrame.width + dx)
            r.size.height = max(minSize, initialWindowFrame.height + dy)
        case .topLeft:
            r.origin.x = initialWindowFrame.origin.x + dx
            r.size.width = max(minSize, initialWindowFrame.width - dx)
            r.size.height = max(minSize, initialWindowFrame.height + dy)
        case .bottomRight:
            r.size.width = max(minSize, initialWindowFrame.width + dx)
            r.origin.y = initialWindowFrame.origin.y + dy
            r.size.height = max(minSize, initialWindowFrame.height - dy)
        case .bottomLeft:
            r.origin.x = initialWindowFrame.origin.x + dx
            r.size.width = max(minSize, initialWindowFrame.width - dx)
            r.origin.y = initialWindowFrame.origin.y + dy
            r.size.height = max(minSize, initialWindowFrame.height - dy)
        case .none:
            break
        }

        return r
    }

    // MARK: - Cursor

    override func resetCursorRects() {
        let h = handleSize
        let b = bounds

        addCursorRect(CGRect(x: 0, y: 0, width: h, height: h), cursor: .crosshair)
        addCursorRect(CGRect(x: b.width - h, y: 0, width: h, height: h), cursor: .crosshair)
        addCursorRect(CGRect(x: 0, y: b.height - h, width: h, height: h), cursor: .crosshair)
        addCursorRect(CGRect(x: b.width - h, y: b.height - h, width: h, height: h), cursor: .crosshair)

        addCursorRect(CGRect(x: h, y: 0, width: b.width - 2*h, height: h), cursor: .resizeUpDown)
        addCursorRect(CGRect(x: h, y: b.height - h, width: b.width - 2*h, height: h), cursor: .resizeUpDown)
        addCursorRect(CGRect(x: 0, y: h, width: h, height: b.height - 2*h), cursor: .resizeLeftRight)
        addCursorRect(CGRect(x: b.width - h, y: h, width: h, height: b.height - 2*h), cursor: .resizeLeftRight)
    }
}

// MARK: - Title Editing Delegate

extension GlassFrameView: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        frameGroup.title = titleLabel.stringValue
        delegate?.glassFrameDidUpdate(self)
    }
}

// MARK: - Delegate Protocol

protocol GlassFrameViewDelegate: AnyObject {
    func glassFrameDidUpdate(_ view: GlassFrameView)
    func glassFrameDidMove(_ view: GlassFrameView, to rect: CGRect)
    func glassFrameDidRequestDelete(_ view: GlassFrameView)
}
