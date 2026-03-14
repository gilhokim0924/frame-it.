import SwiftUI
import Cocoa
import UniformTypeIdentifiers

// MARK: - GlassFrameView
// A configurable desktop frame with outline, solid-color, or image backgrounds.

class GlassFrameView: FirstMouseView {

    var frameGroup: FrameGroup {
        didSet { updateContent() }
    }

    weak var delegate: GlassFrameViewDelegate?

    var isEditMode = false {
        didSet { updateContent() }
    }

    // Subviews
    private let clearGlassView = NSGlassEffectView()
    private let backgroundImageView = BackgroundImageView()
    private let fillView = NonInteractiveView()
    private let titleBadgeView = NonInteractiveView()
    private let titleLabel = TitleTextView()
    private var buttonsHosting: NSHostingView<EditButtonsView>?
    private let frameCornerRadius: CGFloat = 22
    private var lastLoadedBackgroundImagePath: String?
    private var lockedWindowFrameAfterTitleChange: CGRect?

    // Interaction state
    private var initialMouseLocation: NSPoint = .zero
    private var initialWindowFrame: CGRect = .zero
    private var resizeEdge: ResizeEdge = .none
    private var isDraggingOrResizing = false
    private let handleSize: CGFloat = 10

    // Borders
    private let outlineLayer = CAShapeLayer()
    private let editBorderLayer = CAShapeLayer()

    // MARK: - Init

    init(frameGroup: FrameGroup) {
        self.frameGroup = frameGroup
        super.init(frame: NSRect(origin: .zero, size: frameGroup.rect.cgRect.size))
        wantsLayer = true
        layer?.backgroundColor = .clear
        setupBackgroundViews()
        setupTitleBadge()
        setupBorderLayers()
        updateContent()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupBackgroundViews() {
        clearGlassView.translatesAutoresizingMaskIntoConstraints = false
        clearGlassView.style = .clear
        clearGlassView.cornerRadius = frameCornerRadius
        addSubview(clearGlassView)

        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        backgroundImageView.wantsLayer = true
        backgroundImageView.layer?.cornerRadius = frameCornerRadius
        backgroundImageView.layer?.masksToBounds = true
        addSubview(backgroundImageView)

        fillView.translatesAutoresizingMaskIntoConstraints = false
        fillView.wantsLayer = true
        fillView.layer?.cornerRadius = frameCornerRadius
        fillView.layer?.masksToBounds = true
        addSubview(fillView)

        NSLayoutConstraint.activate([
            clearGlassView.topAnchor.constraint(equalTo: topAnchor),
            clearGlassView.leadingAnchor.constraint(equalTo: leadingAnchor),
            clearGlassView.trailingAnchor.constraint(equalTo: trailingAnchor),
            clearGlassView.bottomAnchor.constraint(equalTo: bottomAnchor),

            backgroundImageView.topAnchor.constraint(equalTo: topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: bottomAnchor),

            fillView.topAnchor.constraint(equalTo: topAnchor),
            fillView.leadingAnchor.constraint(equalTo: leadingAnchor),
            fillView.trailingAnchor.constraint(equalTo: trailingAnchor),
            fillView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func setupTitleBadge() {
        titleBadgeView.wantsLayer = true
        titleBadgeView.layer?.cornerRadius = 14
        titleBadgeView.layer?.masksToBounds = true
        addSubview(titleBadgeView)

        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleBadgeView.addSubview(titleLabel)
    }

    private func setupBorderLayers() {
        outlineLayer.fillColor = nil
        outlineLayer.lineWidth = 1.25
        layer?.addSublayer(outlineLayer)

        editBorderLayer.fillColor = nil
        editBorderLayer.strokeColor = NSColor.white.withAlphaComponent(0.6).cgColor
        editBorderLayer.lineWidth = 1.5
        editBorderLayer.lineDashPattern = [6, 4]
        editBorderLayer.isHidden = true
        layer?.addSublayer(editBorderLayer)
    }

    override func layout() {
        super.layout()
        let path = CGPath(roundedRect: bounds.insetBy(dx: 1, dy: 1),
                          cornerWidth: frameCornerRadius, cornerHeight: frameCornerRadius, transform: nil)
        outlineLayer.frame = bounds
        outlineLayer.path = path
        editBorderLayer.frame = bounds
        editBorderLayer.path = path
        layoutTitleBadge()
        restoreLockedWindowFrameIfNeeded()
    }

    // MARK: - Content Update

    private func updateContent() {
        titleLabel.string = frameGroup.title
        titleLabel.maximumNumberOfLines = isEditMode ? 2 : 0
        titleLabel.truncatesLastVisibleLine = false
        applyBackgroundAppearance()
        needsLayout = true
        editBorderLayer.isHidden = !isEditMode

        if isEditMode {
            showEditButtons()
        } else {
            hideEditButtons()
        }
    }

    private func applyBackgroundAppearance() {
        let appearance = currentAppearance()

        clearGlassView.isHidden = !appearance.usesGlass
        fillView.layer?.backgroundColor = appearance.fillColor?.cgColor
        fillView.isHidden = appearance.fillColor == nil

        backgroundImageView.isHidden = appearance.image == nil
        backgroundImageView.image = appearance.image

        titleBadgeView.layer?.backgroundColor = appearance.titleBadgeColor.cgColor
        titleLabel.textColor = appearance.titleTextColor

        outlineLayer.strokeColor = appearance.outlineColor.cgColor
    }

    private func layoutTitleBadge() {
        let topPadding: CGFloat = 10
        let leadingPadding: CGFloat = 10
        let trailingPadding: CGFloat = 10
        let interItemGap: CGFloat = 10
        let horizontalInset: CGFloat = 12
        let verticalInset: CGFloat = 8
        let minBadgeHeight: CGFloat = 32
        let maxBadgeHeight = max(minBadgeHeight, bounds.height - (topPadding * 2))
        let minBadgeWidth: CGFloat = 64
        let minimumLabelWidth = max(24, minBadgeWidth - (horizontalInset * 2))

        let rightLimit = (isEditMode ? buttonsHosting?.frame.minX : nil) ?? bounds.maxX
        let maxBadgeWidth = max(minBadgeWidth, rightLimit - leadingPadding - trailingPadding - (isEditMode ? interItemGap : 0))
        let maximumLabelWidth = max(minimumLabelWidth, maxBadgeWidth - (horizontalInset * 2))

        let font = titleLabel.font ?? .systemFont(ofSize: 12, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let attributedTitle = NSAttributedString(string: frameGroup.title, attributes: attributes)
        let twoLineHeight = ceil((font.ascender - font.descender + font.leading) * 2)

        let singleLineWidth = ceil(attributedTitle.boundingRect(
            with: NSSize(width: .greatestFiniteMagnitude, height: font.pointSize * 2),
            options: [.usesFontLeading]
        ).width)

        func measuredHeight(for labelWidth: CGFloat) -> CGFloat {
            ceil(attributedTitle.boundingRect(
                with: NSSize(width: labelWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            ).height)
        }

        let naturalBadgeWidth = max(minBadgeWidth, singleLineWidth + (horizontalInset * 2))
        let badgeWidth: CGFloat
        let labelMaxWidth: CGFloat

        if naturalBadgeWidth <= maxBadgeWidth {
            badgeWidth = naturalBadgeWidth
            labelMaxWidth = max(minimumLabelWidth, badgeWidth - (horizontalInset * 2))
        } else if measuredHeight(for: maximumLabelWidth) <= twoLineHeight {
            var low = minimumLabelWidth
            var high = maximumLabelWidth

            while high - low > 1 {
                let mid = floor((low + high) / 2)
                if measuredHeight(for: mid) <= twoLineHeight {
                    high = mid
                } else {
                    low = mid + 1
                }
            }

            labelMaxWidth = high
            badgeWidth = max(minBadgeWidth, labelMaxWidth + (horizontalInset * 2))
        } else {
            labelMaxWidth = maximumLabelWidth
            badgeWidth = maxBadgeWidth
        }

        let wrappedHeight = measuredHeight(for: labelMaxWidth)

        let badgeHeight = min(maxBadgeHeight, max(minBadgeHeight, wrappedHeight + (verticalInset * 2)))
        let badgeY = bounds.height - topPadding - badgeHeight
        let labelHeight = min(wrappedHeight, badgeHeight - (verticalInset * 2))
        let labelY = max(verticalInset, floor((badgeHeight - labelHeight) / 2))

        titleBadgeView.frame = CGRect(
            x: leadingPadding,
            y: badgeY,
            width: badgeWidth,
            height: badgeHeight
        ).integral
        titleLabel.frame = CGRect(
            x: horizontalInset,
            y: labelY,
            width: badgeWidth - (horizontalInset * 2),
            height: labelHeight
        ).integral
    }

    private func restoreLockedWindowFrameIfNeeded() {
        guard let lockedFrame = lockedWindowFrameAfterTitleChange, let window else { return }
        guard window.frame != lockedFrame else { return }

        window.setFrame(lockedFrame, display: true)
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

        addSubview(hosting)

        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            hosting.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
        ])

        buttonsHosting = hosting
        needsLayout = true
    }

    private func hideEditButtons() {
        buttonsHosting?.removeFromSuperview()
        buttonsHosting = nil
        needsLayout = true
    }

    private func currentAppearance() -> FrameAppearance {
        switch frameGroup.backgroundStyle {
        case .outline:
            return FrameAppearance(
                fillColor: nil,
                image: nil,
                outlineColor: NSColor.white.withAlphaComponent(0.55),
                titleBadgeColor: NSColor.black.withAlphaComponent(0.55),
                titleTextColor: .white
            )
        case .clear:
            return FrameAppearance(
                fillColor: NSColor.black.withAlphaComponent(0.16),
                image: nil,
                outlineColor: NSColor.white.withAlphaComponent(0.42),
                titleBadgeColor: NSColor.black.withAlphaComponent(0.52),
                titleTextColor: .white,
                usesGlass: true
            )
        case .solidColor:
            let color = frameGroup.backgroundColor
            return FrameAppearance(
                fillColor: color.fillColor,
                image: nil,
                outlineColor: color.outlineColor,
                titleBadgeColor: titleBadgeColor(for: color),
                titleTextColor: color.titleTextColor
            )
        case .image:
            return FrameAppearance(
                fillColor: nil,
                image: loadBackgroundImage(),
                outlineColor: NSColor.white.withAlphaComponent(0.55),
                titleBadgeColor: NSColor.black.withAlphaComponent(0.58),
                titleTextColor: .white
            )
        }
    }

    private func titleBadgeColor(for color: FrameBackgroundColor) -> NSColor {
        switch color {
        case .black:
            return NSColor.white.withAlphaComponent(0.18)
        default:
            return NSColor.white.withAlphaComponent(0.62)
        }
    }

    private func loadBackgroundImage() -> NSImage? {
        guard let path = frameGroup.backgroundImagePath, !path.isEmpty else {
            lastLoadedBackgroundImagePath = nil
            return nil
        }

        if lastLoadedBackgroundImagePath == path, let currentImage = backgroundImageView.image {
            return currentImage
        }

        let image = NSImage(contentsOfFile: path)
        lastLoadedBackgroundImagePath = path
        return image
    }

    private func persistFrameChange() {
        updateContent()
        delegate?.glassFrameDidUpdate(self)
    }

    private var snapPreviewWindow: NSWindow?

    // MARK: - Snap Preview

    private func showSnapPreview(for rect: CGRect) {
        guard isEditMode else { return }
        let snapped = snappedRect(for: rect)

        if let preview = snapPreviewWindow {
            // Animate to new grid position for smooth leading effect
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                preview.animator().setFrame(snapped, display: true)
            }
            (preview.contentView as? SnapPreviewView)?.needsDisplay = true
        } else {
            let preview = NSWindow(
                contentRect: snapped,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            preview.isOpaque = false
            preview.backgroundColor = .clear
            preview.hasShadow = false
            preview.ignoresMouseEvents = true
            preview.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 2)

            let previewView = SnapPreviewView(frame: NSRect(origin: .zero, size: snapped.size))
            previewView.autoresizingMask = [.width, .height]
            preview.contentView = previewView

            preview.orderFront(nil)
            snapPreviewWindow = preview
        }
    }

    private func hideSnapPreview() {
        snapPreviewWindow?.orderOut(nil)
        snapPreviewWindow = nil
    }

    // MARK: - Cursor Feedback

    override func mouseMoved(with event: NSEvent) {
        guard isEditMode else {
            NSCursor.arrow.set()
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        let edge = detectEdge(at: point)
        switch edge {
        case .left, .right:
            NSCursor.resizeLeftRight.set()
        case .top, .bottom:
            NSCursor.resizeUpDown.set()
        case .topLeft, .bottomRight:
            NSCursor.closedHand.set()  // diagonal NW-SE
        case .topRight, .bottomLeft:
            NSCursor.closedHand.set()  // diagonal NE-SW
        case .none:
            NSCursor.openHand.set()
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        // Remove old tracking areas
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        // Add new one covering entire view
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    // MARK: - Mouse Handling

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            renameAction()
            return
        }

        guard let window = window else { return }
        let pointInView = convert(event.locationInWindow, from: nil)
        let edge = detectEdge(at: pointInView)

        if isEditMode {
            let titleAreaMinY = min(
                titleBadgeView.frame.minY,
                buttonsHosting?.frame.minY ?? titleBadgeView.frame.minY
            ) - 8

            if pointInView.y > titleAreaMinY, edge == .none {
                return
            }
        }

        initialMouseLocation = NSEvent.mouseLocation
        initialWindowFrame = window.frame
        resizeEdge = edge
        isDraggingOrResizing = true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point) else { return nil }

        if isEditMode, let buttonsHosting {
            let pointInButtons = convert(point, to: buttonsHosting)
            if buttonsHosting.bounds.contains(pointInButtons) {
                return buttonsHosting.hitTest(pointInButtons) ?? buttonsHosting
            }
        }

        return self
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDraggingOrResizing, let window = window else { return }
        let currentMouse = NSEvent.mouseLocation
        let dx = currentMouse.x - initialMouseLocation.x
        let dy = currentMouse.y - initialMouseLocation.y

        if resizeEdge != .none {
            let newFrame = computeResize(dx: dx, dy: dy)
            window.setFrame(newFrame, display: true)
            showSnapPreview(for: newFrame)
        } else {
            var origin = initialWindowFrame.origin
            origin.x += dx
            origin.y += dy

            let proposedFrame = CGRect(origin: origin, size: window.frame.size)
            let screen = targetScreen(for: proposedFrame, mouseLocation: currentMouse)
            let visible = screen.visibleFrame
            let size = window.frame.size
            origin.x = max(visible.minX, min(origin.x, visible.maxX - size.width))
            origin.y = max(visible.minY, min(origin.y, visible.maxY - size.height))

            window.setFrameOrigin(origin)
            showSnapPreview(for: CGRect(origin: origin, size: size))
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard isDraggingOrResizing else { return }
        isDraggingOrResizing = false
        resizeEdge = .none
        guard let window = window else { return }

        // Snap to grid with smooth animation
        let snappedFrame = snappedRect(for: window.frame)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(snappedFrame, display: true)
        }, completionHandler: { [weak self] in
            self?.hideSnapPreview()
        })

        delegate?.glassFrameDidMove(self, to: snappedFrame)
    }

    private func snappedRect(for rect: CGRect) -> CGRect {
        DesktopGrid(screen: targetScreen(for: rect)).snapRect(rect)
    }

    private func targetScreen(for rect: CGRect, mouseLocation: NSPoint? = nil) -> NSScreen {
        if let mouseLocation,
           let mouseScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
            return mouseScreen
        }

        let bestScreen = NSScreen.screens.max { lhs, rhs in
            intersectionArea(between: lhs.frame, and: rect) < intersectionArea(between: rhs.frame, and: rect)
        }

        if let bestScreen, intersectionArea(between: bestScreen.frame, and: rect) > 0 {
            return bestScreen
        }

        return window?.screen ?? NSScreen.main ?? NSScreen.screens.first!
    }

    private func intersectionArea(between lhs: CGRect, and rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull else { return 0 }
        return intersection.width * intersection.height
    }

    // MARK: - Context Menu

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()

        let renameItem = NSMenuItem(title: "Rename", action: #selector(renameAction), keyEquivalent: "")
        renameItem.target = self
        menu.addItem(renameItem)

        menu.addItem(.separator())

        let backgroundItem = NSMenuItem(title: "Background", action: nil, keyEquivalent: "")
        backgroundItem.submenu = makeBackgroundMenu()
        menu.addItem(backgroundItem)

        menu.addItem(.separator())

        let deleteItem = NSMenuItem(title: "Delete", action: #selector(deleteAction), keyEquivalent: "")
        deleteItem.target = self
        menu.addItem(deleteItem)

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func renameAction() {
        guard let window else { return }

        let alert = NSAlert()
        alert.messageText = "Rename Frame"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.stringValue = frameGroup.title
        alert.accessoryView = textField
        let lockedRect = window.frame

        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self else { return }
            self.applyRenamedTitle(textField.stringValue, lockedRect: lockedRect)
        }
    }

    private func applyRenamedTitle(_ title: String, lockedRect: CGRect) {
        lockedWindowFrameAfterTitleChange = lockedRect

        frameGroup.title = title
        frameGroup.rect = CodableRect(cgRect: lockedRect)
        updateContent()
        window?.setFrame(lockedRect, display: true)

        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }

            self.frameGroup.rect = CodableRect(cgRect: lockedRect)
            window.setFrame(lockedRect, display: true)
            self.delegate?.glassFrameDidUpdate(self)
            self.lockedWindowFrameAfterTitleChange = nil
        }
    }

    @objc private func deleteAction() {
        delegate?.glassFrameDidRequestDelete(self)
    }

    private func makeBackgroundMenu() -> NSMenu {
        let menu = NSMenu()

        let outlineItem = makeMenuItem(title: "Frame Only", action: #selector(setOutlineBackground))
        outlineItem.state = frameGroup.backgroundStyle == .outline ? .on : .off
        menu.addItem(outlineItem)

        let clearItem = makeMenuItem(title: "Clear", action: #selector(setClearBackground))
        clearItem.state = frameGroup.backgroundStyle == .clear ? .on : .off
        menu.addItem(clearItem)

        menu.addItem(.separator())

        for color in FrameBackgroundColor.allCases {
            let item = makeMenuItem(title: color.title, action: #selector(setSolidColor(_:)))
            item.representedObject = color.rawValue
            item.image = color.menuSwatchImage
            item.state = frameGroup.backgroundStyle == .solidColor && frameGroup.backgroundColor == color ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let imageItem = makeMenuItem(title: "Choose Image...", action: #selector(chooseBackgroundImage))
        menu.addItem(imageItem)

        if frameGroup.backgroundImagePath != nil {
            let clearImageItem = makeMenuItem(title: "Remove Image", action: #selector(removeBackgroundImage))
            menu.addItem(clearImageItem)
        }

        return menu
    }

    private func makeMenuItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func setOutlineBackground() {
        frameGroup.backgroundStyle = .outline
        frameGroup.backgroundImagePath = nil
        persistFrameChange()
    }

    @objc private func setClearBackground() {
        frameGroup.backgroundStyle = .clear
        frameGroup.backgroundImagePath = nil
        persistFrameChange()
    }

    @objc private func setSolidColor(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let color = FrameBackgroundColor(rawValue: rawValue) else { return }

        frameGroup.backgroundStyle = .solidColor
        frameGroup.backgroundColor = color
        frameGroup.backgroundImagePath = nil
        persistFrameChange()
    }

    @objc private func chooseBackgroundImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]

        if panel.runModal() == .OK, let url = panel.url {
            frameGroup.backgroundStyle = .image
            frameGroup.backgroundImagePath = url.path
            persistFrameChange()
        }
    }

    @objc private func removeBackgroundImage() {
        frameGroup.backgroundImagePath = nil
        frameGroup.backgroundStyle = .outline
        persistFrameChange()
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

private struct FrameAppearance {
    let fillColor: NSColor?
    let image: NSImage?
    let outlineColor: NSColor
    let titleBadgeColor: NSColor
    let titleTextColor: NSColor
    let usesGlass: Bool

    init(
        fillColor: NSColor?,
        image: NSImage?,
        outlineColor: NSColor,
        titleBadgeColor: NSColor,
        titleTextColor: NSColor,
        usesGlass: Bool = false
    ) {
        self.fillColor = fillColor
        self.image = image
        self.outlineColor = outlineColor
        self.titleBadgeColor = titleBadgeColor
        self.titleTextColor = titleTextColor
        self.usesGlass = usesGlass
    }
}

// MARK: - Edit Buttons

struct EditButtonsView: View {
    var onDelete: () -> Void
    var onDone: () -> Void
    @State private var deleteHovered = false
    @State private var doneHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .background(Circle().fill(deleteHovered ? Color.red.opacity(0.85) : Color.black.opacity(0.72)))
            .animation(.easeInOut(duration: 0.15), value: deleteHovered)
            .onHover { deleteHovered = $0 }

            Button(action: onDone) {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .background(Circle().fill(doneHovered ? Color.green.opacity(0.85) : Color.black.opacity(0.72)))
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

// MARK: - Snap Preview View (dotted outline)

class SnapPreviewView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)

        let inset = bounds.insetBy(dx: 1.5, dy: 1.5)
        let path = CGPath(roundedRect: inset, cornerWidth: 18, cornerHeight: 18, transform: nil)

        // Dotted outline
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.6).cgColor)
        ctx.setLineWidth(2.0)
        ctx.setLineDash(phase: 0, lengths: [8, 5])
        ctx.addPath(path)
        ctx.strokePath()

        // Subtle fill
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.05).cgColor)
        ctx.addPath(path)
        ctx.fillPath()
    }

    override func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)
        needsDisplay = true
    }
}

private final class NonInteractiveView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

private final class BackgroundImageView: NSView {
    var image: NSImage? {
        didSet {
            needsDisplay = true
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let image else { return }

        let rect = aspectFillRect(for: image.size, in: bounds).integral

        image.draw(
            in: rect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
    }

    private func aspectFillRect(for imageSize: NSSize, in bounds: NSRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, bounds.width > 0, bounds.height > 0 else {
            return bounds
        }

        let widthScale = bounds.width / imageSize.width
        let heightScale = bounds.height / imageSize.height
        let scale = max(widthScale, heightScale)
        let scaledSize = NSSize(width: imageSize.width * scale, height: imageSize.height * scale)

        return CGRect(
            x: bounds.midX - (scaledSize.width / 2),
            y: bounds.midY - (scaledSize.height / 2),
            width: scaledSize.width,
            height: scaledSize.height
        )
    }
}

private final class TitleTextView: NSTextView {
    var maximumNumberOfLines: Int = 0 {
        didSet {
            textContainer?.maximumNumberOfLines = maximumNumberOfLines
            needsDisplay = true
        }
    }

    var truncatesLastVisibleLine: Bool = false {
        didSet {
            textContainer?.lineBreakMode = truncatesLastVisibleLine ? .byTruncatingTail : .byWordWrapping
            needsDisplay = true
        }
    }

    override var string: String {
        didSet { syncTextStorage() }
    }

    override var textColor: NSColor! {
        didSet { syncTextStorage() }
    }

    override var font: NSFont? {
        didSet { syncTextStorage() }
    }

    init() {
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: .zero)
        textContainer.lineFragmentPadding = 0
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = true
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)

        super.init(frame: .zero, textContainer: textContainer)

        isEditable = false
        isSelectable = false
        isRichText = false
        drawsBackground = false
        backgroundColor = .clear
        textContainerInset = .zero
        textContainer.lineBreakMode = .byWordWrapping
        syncTextStorage()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func didChangeText() {
        super.didChangeText()
        needsDisplay = true
    }

    private func syncTextStorage() {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? .systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: textColor ?? NSColor.white
        ]
        textStorage?.setAttributedString(NSAttributedString(string: string, attributes: attributes))
        needsDisplay = true
    }
}
