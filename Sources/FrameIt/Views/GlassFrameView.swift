import SwiftUI
import Cocoa

// MARK: - Accent Colors for Frames

struct FrameColors {
    static let palettes: [(color: Color, name: String)] = [
        (.white.opacity(0.15), "Clear"),
        (.blue, "Blue"),
        (.purple, "Purple"),
        (.pink, "Pink"),
        (.orange, "Orange"),
        (.green, "Green"),
        (.teal, "Teal"),
    ]

    static func color(for index: Int) -> Color {
        palettes[index % palettes.count].color
    }

    static func name(for index: Int) -> String {
        palettes[index % palettes.count].name
    }
}

// MARK: - SwiftUI Liquid Glass Frame Content

struct LiquidGlassFrameContent: View {
    let title: String
    let colorIndex: Int
    let isEditing: Bool
    var onDelete: () -> Void
    var onDone: () -> Void

    var body: some View {
        ZStack {
            // Main Liquid Glass background
            RoundedRectangle(cornerRadius: 20)
                .fill(.clear)
                .glassEffect(.regular.tint(FrameColors.color(for: colorIndex)),
                             in: .rect(cornerRadius: 20))

            // Content overlay
            VStack(alignment: .leading, spacing: 0) {
                // Title bar area
                HStack {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    // Edit-mode buttons
                    if isEditing {
                        HStack(spacing: 6) {
                            // Delete button (glass circle)
                            Button(action: onDelete) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.red)
                                    .frame(width: 24, height: 24)
                            }
                            .buttonStyle(.plain)
                            .glassEffect(.regular.tint(.red.opacity(0.3)),
                                         in: .circle)

                            // Done button (glass circle)
                            Button(action: onDone) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.green)
                                    .frame(width: 24, height: 24)
                            }
                            .buttonStyle(.plain)
                            .glassEffect(.regular.tint(.green.opacity(0.3)),
                                         in: .circle)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)

                Spacer()
            }

            // Edit mode dashed border
            if isEditing {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }
}

// MARK: - GlassFrameView (AppKit wrapper)
// Content view for a FrameWindow. Wraps SwiftUI Liquid Glass content
// and handles drag-to-move / edge-resize.

class GlassFrameView: FirstMouseView {

    var frameGroup: FrameGroup {
        didSet { updateSwiftUIContent() }
    }

    weak var delegate: GlassFrameViewDelegate?

    var isEditMode = false {
        didSet { updateSwiftUIContent() }
    }

    // SwiftUI hosting
    private var hostingView: NSHostingView<LiquidGlassFrameContent>!

    // Interaction state
    private var initialMouseLocation: NSPoint = .zero
    private var initialWindowFrame: CGRect = .zero
    private var resizeEdge: ResizeEdge = .none
    private var isDraggingOrResizing = false

    private let handleSize: CGFloat = 10

    // MARK: - Init

    init(frameGroup: FrameGroup) {
        self.frameGroup = frameGroup
        super.init(frame: NSRect(origin: .zero, size: frameGroup.rect.cgRect.size))
        setupHostingView()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - SwiftUI Hosting

    private func setupHostingView() {
        let content = makeContent()
        hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func makeContent() -> LiquidGlassFrameContent {
        LiquidGlassFrameContent(
            title: frameGroup.title,
            colorIndex: frameGroup.colorIndex,
            isEditing: isEditMode,
            onDelete: { [weak self] in
                guard let self = self else { return }
                self.delegate?.glassFrameDidRequestDelete(self)
            },
            onDone: {
                NotificationCenter.default.post(name: .frameDoneEditing, object: nil)
            }
        )
    }

    private func updateSwiftUIContent() {
        hostingView?.rootView = makeContent()
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
        isDraggingOrResizing = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDraggingOrResizing, let window = window else { return }
        let currentMouse = NSEvent.mouseLocation
        let dx = currentMouse.x - initialMouseLocation.x
        let dy = currentMouse.y - initialMouseLocation.y

        if resizeEdge != .none {
            let newFrame = computeResize(dx: dx, dy: dy)
            window.setFrame(newFrame, display: true)
        } else {
            var newOrigin = initialWindowFrame.origin
            newOrigin.x += dx
            newOrigin.y += dy
            window.setFrameOrigin(newOrigin)
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard isDraggingOrResizing else { return }
        isDraggingOrResizing = false
        resizeEdge = .none
        guard let window = window else { return }
        delegate?.glassFrameDidMove(self, to: window.frame)
    }

    // MARK: - Context Menu

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()

        let renameItem = NSMenuItem(title: "Rename", action: #selector(renameAction), keyEquivalent: "")
        renameItem.target = self
        menu.addItem(renameItem)

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
        // Show a simple rename alert
        let alert = NSAlert()
        alert.messageText = "Rename Frame"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.stringValue = frameGroup.title
        alert.accessoryView = textField

        if alert.runModal() == .alertFirstButtonReturn {
            frameGroup.title = textField.stringValue
            updateSwiftUIContent()
            delegate?.glassFrameDidUpdate(self)
        }
    }

    @objc private func changeColorAction(_ sender: NSMenuItem) {
        frameGroup.colorIndex = sender.tag
        updateSwiftUIContent()
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
