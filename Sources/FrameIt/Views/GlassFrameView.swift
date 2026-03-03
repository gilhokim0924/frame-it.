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

    // Edit mode — shows/hides indicator buttons
    var isEditMode = false {
        didSet { updateEditIndicators() }
    }

    // Subviews
    private let effectView = NSVisualEffectView()
    private let tintOverlay = NSView()
    private let titleLabel = NSTextField()
    private let borderLayer = CAShapeLayer()

    // Edit-mode indicator buttons
    private let deleteButton = NSButton()
    private let doneButton = NSButton()
    private let editBorderLayer = CAShapeLayer()

    // Interaction state
    private var initialMouseLocation: NSPoint = .zero
    private var initialWindowFrame: CGRect = .zero
    private var resizeEdge: ResizeEdge = .none

    private let handleSize: CGFloat = 8
    private let cornerRadius: CGFloat = 14
    private let buttonSize: CGFloat = 22

    // MARK: - Init

    init(frameGroup: FrameGroup) {
        self.frameGroup = frameGroup
        super.init(frame: NSRect(origin: .zero, size: frameGroup.rect.cgRect.size))
        setupViews()
        setupEditButtons()
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

        // Border (normal mode)
        borderLayer.fillColor = nil
        borderLayer.lineWidth = 1.0
        layer?.addSublayer(borderLayer)

        // Edit border (dashed, only shown in edit mode)
        editBorderLayer.fillColor = nil
        editBorderLayer.strokeColor = NSColor.white.withAlphaComponent(0.6).cgColor
        editBorderLayer.lineWidth = 2.0
        editBorderLayer.lineDashPattern = [6, 4]
        editBorderLayer.isHidden = true
        layer?.addSublayer(editBorderLayer)

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
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -36),
            titleLabel.heightAnchor.constraint(equalToConstant: 18),
        ])
    }

    private func setupEditButtons() {
        // ✕ Delete button — top-left corner
        configureCircleButton(deleteButton, symbol: "xmark", color: NSColor.systemRed.withAlphaComponent(0.8))
        deleteButton.action = #selector(deleteAction)
        deleteButton.target = self
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.isHidden = true
        addSubview(deleteButton)

        // ✓ Done button — top-right corner
        configureCircleButton(doneButton, symbol: "checkmark", color: NSColor.systemGreen.withAlphaComponent(0.8))
        doneButton.action = #selector(doneAction)
        doneButton.target = self
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.isHidden = true
        addSubview(doneButton)

        NSLayoutConstraint.activate([
            // Delete button — top-left, slightly inset
            deleteButton.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            deleteButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -30),
            deleteButton.widthAnchor.constraint(equalToConstant: buttonSize),
            deleteButton.heightAnchor.constraint(equalToConstant: buttonSize),

            // Done button — top-right
            doneButton.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            doneButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            doneButton.widthAnchor.constraint(equalToConstant: buttonSize),
            doneButton.heightAnchor.constraint(equalToConstant: buttonSize),
        ])
    }

    private func configureCircleButton(_ button: NSButton, symbol: String, color: NSColor) {
        button.bezelStyle = .circular
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = buttonSize / 2
        button.layer?.backgroundColor = color.cgColor

        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .bold)
            button.image = image.withSymbolConfiguration(config)
            button.contentTintColor = .white
        } else {
            button.title = symbol == "xmark" ? "✕" : "✓"
        }
    }

    // MARK: - Edit Mode Indicators

    private func updateEditIndicators() {
        deleteButton.isHidden = !isEditMode
        doneButton.isHidden = !isEditMode
        editBorderLayer.isHidden = !isEditMode
        borderLayer.isHidden = isEditMode
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
        editBorderLayer.path = path
        editBorderLayer.frame = bounds
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

    @objc private func doneAction() {
        // Notify to exit edit mode
        NotificationCenter.default.post(name: .frameDoneEditing, object: nil)
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

// MARK: - Notifications

extension Notification.Name {
    static let frameDoneEditing = Notification.Name("frameDoneEditing")
}
