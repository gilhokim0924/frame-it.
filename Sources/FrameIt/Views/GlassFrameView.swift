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
    private var dragOrigin: NSPoint?
    private var resizeEdge: ResizeEdge = .none
    private var initialFrame: CGRect = .zero

    private let handleSize: CGFloat = 8
    private let cornerRadius: CGFloat = 14

    // MARK: - Init

    init(frameGroup: FrameGroup) {
        self.frameGroup = frameGroup
        super.init(frame: frameGroup.rect.cgRect)
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

    // MARK: - Mouse Handling

    override func mouseDown(with event: NSEvent) {
        // Double-click to rename
        if event.clickCount == 2 {
            renameAction()
            return
        }

        guard let superview = superview else { return }
        let loc = superview.convert(event.locationInWindow, from: nil)
        initialFrame = frame
        resizeEdge = detectEdge(at: convert(event.locationInWindow, from: nil))

        if resizeEdge == .none {
            dragOrigin = loc
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let superview = superview else { return }
        let loc = superview.convert(event.locationInWindow, from: nil)

        if resizeEdge != .none {
            applyResize(to: loc)
        } else if let origin = dragOrigin {
            let dx = loc.x - origin.x
            let dy = loc.y - origin.y
            frame = CGRect(
                x: initialFrame.origin.x + dx,
                y: initialFrame.origin.y + dy,
                width: initialFrame.width,
                height: initialFrame.height
            )
        }
    }

    override func mouseUp(with event: NSEvent) {
        dragOrigin = nil
        resizeEdge = .none

        // Persist the new rect
        frameGroup.rect = CodableRect(cgRect: frame)
        delegate?.glassFrameDidUpdate(self)
    }

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
        // Make the title label editable temporarily
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

    private func applyResize(to point: NSPoint) {
        var newFrame = initialFrame
        let minSize: CGFloat = 80

        switch resizeEdge {
        case .right:
            newFrame.size.width = max(minSize, point.x - initialFrame.origin.x)
        case .left:
            let dx = point.x - initialFrame.origin.x
            newFrame.origin.x = initialFrame.origin.x + dx
            newFrame.size.width = max(minSize, initialFrame.width - dx)
        case .top:
            newFrame.size.height = max(minSize, point.y - initialFrame.origin.y)
        case .bottom:
            let dy = point.y - initialFrame.origin.y
            newFrame.origin.y = initialFrame.origin.y + dy
            newFrame.size.height = max(minSize, initialFrame.height - dy)
        case .topRight:
            newFrame.size.width = max(minSize, point.x - initialFrame.origin.x)
            newFrame.size.height = max(minSize, point.y - initialFrame.origin.y)
        case .topLeft:
            let dx = point.x - initialFrame.origin.x
            newFrame.origin.x = initialFrame.origin.x + dx
            newFrame.size.width = max(minSize, initialFrame.width - dx)
            newFrame.size.height = max(minSize, point.y - initialFrame.origin.y)
        case .bottomRight:
            let dy = point.y - initialFrame.origin.y
            newFrame.size.width = max(minSize, point.x - initialFrame.origin.x)
            newFrame.origin.y = initialFrame.origin.y + dy
            newFrame.size.height = max(minSize, initialFrame.height - dy)
        case .bottomLeft:
            let dx = point.x - initialFrame.origin.x
            let dy = point.y - initialFrame.origin.y
            newFrame.origin.x = initialFrame.origin.x + dx
            newFrame.size.width = max(minSize, initialFrame.width - dx)
            newFrame.origin.y = initialFrame.origin.y + dy
            newFrame.size.height = max(minSize, initialFrame.height - dy)
        case .none:
            break
        }

        frame = newFrame
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
    func glassFrameDidRequestDelete(_ view: GlassFrameView)
}
