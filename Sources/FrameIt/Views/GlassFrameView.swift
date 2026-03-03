import SwiftUI
import Cocoa

// MARK: - GlassFrameView
// Uses NSGlassEffectView (Apple's official Liquid Glass API for AppKit)
// with SwiftUI buttons overlaid via NSHostingView for edit controls.

class GlassFrameView: FirstMouseView {

    var frameGroup: FrameGroup {
        didSet { updateContent() }
    }

    weak var delegate: GlassFrameViewDelegate?

    var isEditMode = false {
        didSet { updateContent() }
    }

    // Subviews
    private let glassView = NSGlassEffectView()
    private let titleLabel = NSTextField(labelWithString: "")
    private var buttonsHosting: NSHostingView<EditButtonsView>?

    // Interaction state
    private var initialMouseLocation: NSPoint = .zero
    private var initialWindowFrame: CGRect = .zero
    private var resizeEdge: ResizeEdge = .none
    private var isDraggingOrResizing = false
    private let handleSize: CGFloat = 10

    // Edit mode border
    private let borderLayer = CAShapeLayer()

    // MARK: - Init

    init(frameGroup: FrameGroup) {
        self.frameGroup = frameGroup
        super.init(frame: NSRect(origin: .zero, size: frameGroup.rect.cgRect.size))
        wantsLayer = true
        layer?.backgroundColor = .clear
        setupGlassView()
        setupTitleLabel()
        setupBorderLayer()
        updateContent()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupGlassView() {
        glassView.translatesAutoresizingMaskIntoConstraints = false
        glassView.cornerRadius = 20

        addSubview(glassView)

        NSLayoutConstraint.activate([
            glassView.topAnchor.constraint(equalTo: topAnchor),
            glassView.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassView.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func setupTitleLabel() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        titleLabel.isEditable = false
        titleLabel.isBezeled = false
        titleLabel.drawsBackground = false
        titleLabel.backgroundColor = .clear

        glassView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: glassView.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: glassView.leadingAnchor, constant: 12),
        ])
    }

    private func setupBorderLayer() {
        borderLayer.fillColor = nil
        borderLayer.strokeColor = NSColor.white.withAlphaComponent(0.4).cgColor
        borderLayer.lineWidth = 1.5
        borderLayer.lineDashPattern = [6, 4]
        borderLayer.isHidden = true
        layer?.addSublayer(borderLayer)
    }

    override func layout() {
        super.layout()
        borderLayer.frame = bounds
        let path = CGPath(roundedRect: bounds.insetBy(dx: 1, dy: 1),
                          cornerWidth: 20, cornerHeight: 20, transform: nil)
        borderLayer.path = path
    }

    // MARK: - Content Update

    private func updateContent() {
        titleLabel.stringValue = frameGroup.title
        borderLayer.isHidden = !isEditMode

        if isEditMode {
            showEditButtons()
        } else {
            hideEditButtons()
        }
    }

    private func showEditButtons() {
        if buttonsHosting != nil { return }

        let view = EditButtonsView(
            onDelete: { [weak self] in
                guard let self = self else { return }
                self.delegate?.glassFrameDidRequestDelete(self)
            },
            onDone: {
                NotificationCenter.default.post(name: .frameDoneEditing, object: nil)
            }
        )

        let hosting = NSHostingView(rootView: view)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        hosting.sceneBridgingOptions = []
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear

        glassView.addSubview(hosting)

        NSLayoutConstraint.activate([
            hosting.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            hosting.trailingAnchor.constraint(equalTo: glassView.trailingAnchor, constant: -10),
        ])

        buttonsHosting = hosting
    }

    private func hideEditButtons() {
        buttonsHosting?.removeFromSuperview()
        buttonsHosting = nil
    }

    // Grid snapping
    let grid = DesktopGrid()

    // MARK: - Mouse Handling

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            renameAction()
            return
        }
        guard let window = window else { return }
        initialMouseLocation = NSEvent.mouseLocation
        initialWindowFrame = window.frame
        resizeEdge = detectEdge(at: convert(event.locationInWindow, from: nil))
        isDraggingOrResizing = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDraggingOrResizing, let window = window else { return }
        let currentMouse = NSEvent.mouseLocation
        let dx = currentMouse.x - initialMouseLocation.x
        let dy = currentMouse.y - initialMouseLocation.y

        if resizeEdge != .none {
            window.setFrame(computeResize(dx: dx, dy: dy), display: true)
        } else {
            var origin = initialWindowFrame.origin
            origin.x += dx
            origin.y += dy
            window.setFrameOrigin(origin)
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard isDraggingOrResizing else { return }
        isDraggingOrResizing = false
        let wasResizing = resizeEdge != .none
        resizeEdge = .none
        guard let window = window else { return }

        // Snap to grid with smooth animation
        let currentFrame = window.frame
        let snappedFrame = grid.snapRect(currentFrame)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(snappedFrame, display: true)
        }

        delegate?.glassFrameDidMove(self, to: snappedFrame)
    }

    // MARK: - Context Menu

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()

        let renameItem = NSMenuItem(title: "Rename", action: #selector(renameAction), keyEquivalent: "")
        renameItem.target = self
        menu.addItem(renameItem)

        menu.addItem(.separator())

        let deleteItem = NSMenuItem(title: "Delete", action: #selector(deleteAction), keyEquivalent: "")
        deleteItem.target = self
        menu.addItem(deleteItem)

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func renameAction() {
        let alert = NSAlert()
        alert.messageText = "Rename Frame"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.stringValue = frameGroup.title
        alert.accessoryView = textField

        if alert.runModal() == .alertFirstButtonReturn {
            frameGroup.title = textField.stringValue
            updateContent()
            delegate?.glassFrameDidUpdate(self)
        }
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
            r.origin.x += dx; r.size.width = max(minSize, initialWindowFrame.width - dx)
        case .top:
            r.size.height = max(minSize, initialWindowFrame.height + dy)
        case .bottom:
            r.origin.y += dy; r.size.height = max(minSize, initialWindowFrame.height - dy)
        case .topRight:
            r.size.width = max(minSize, initialWindowFrame.width + dx)
            r.size.height = max(minSize, initialWindowFrame.height + dy)
        case .topLeft:
            r.origin.x += dx; r.size.width = max(minSize, initialWindowFrame.width - dx)
            r.size.height = max(minSize, initialWindowFrame.height + dy)
        case .bottomRight:
            r.size.width = max(minSize, initialWindowFrame.width + dx)
            r.origin.y += dy; r.size.height = max(minSize, initialWindowFrame.height - dy)
        case .bottomLeft:
            r.origin.x += dx; r.size.width = max(minSize, initialWindowFrame.width - dx)
            r.origin.y += dy; r.size.height = max(minSize, initialWindowFrame.height - dy)
        case .none: break
        }
        return r
    }
}

// MARK: - Edit Buttons (SwiftUI with Liquid Glass circles)

struct EditButtonsView: View {
    var onDelete: () -> Void
    var onDone: () -> Void
    @State private var deleteHovered = false
    @State private var doneHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .brightness(deleteHovered ? 0.15 : 0)
            .animation(.easeInOut(duration: 0.15), value: deleteHovered)
            .onHover { deleteHovered = $0 }

            Button(action: onDone) {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .brightness(doneHovered ? 0.15 : 0)
            .animation(.easeInOut(duration: 0.15), value: doneHovered)
            .onHover { doneHovered = $0 }
        }
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
