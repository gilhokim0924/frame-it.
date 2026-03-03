import Cocoa

// MARK: - DesktopGrid
// Reads macOS Finder desktop icon grid settings and provides
// snap-to-grid functionality for frame positioning and sizing.

struct DesktopGrid {

    /// Size of one grid cell (icon + spacing)
    let cellWidth: CGFloat
    let cellHeight: CGFloat

    /// Screen's visible frame (excludes menu bar / dock)
    let screenFrame: CGRect

    // MARK: - Init

    /// Reads Finder preferences for the current screen's desktop grid.
    /// Falls back to 100pt cells if preferences can't be read.
    init(screen: NSScreen? = NSScreen.main) {
        let screenFrame = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        self.screenFrame = screenFrame

        // Read Finder desktop icon settings
        let defaults = UserDefaults(suiteName: "com.apple.finder")
        let desktopSettings = defaults?.dictionary(forKey: "DesktopViewSettings") as? [String: Any]
        let iconSettings = desktopSettings?["IconViewSettings"] as? [String: Any]

        let iconSize = (iconSettings?["iconSize"] as? CGFloat) ?? 64
        let gridSpacing = (iconSettings?["gridSpacing"] as? CGFloat) ?? 54

        // Cell = icon + spacing. macOS uses square cells for the grid.
        let cell = iconSize + gridSpacing
        self.cellWidth = cell
        self.cellHeight = cell
    }

    /// Custom init for testing
    init(cellWidth: CGFloat, cellHeight: CGFloat, screenFrame: CGRect) {
        self.cellWidth = cellWidth
        self.cellHeight = cellHeight
        self.screenFrame = screenFrame
    }

    // MARK: - Snapping

    /// Snap a rect to the nearest grid-aligned position and size.
    /// Position snaps to nearest grid intersection.
    /// Size snaps to nearest whole number of cells.
    func snapRect(_ rect: CGRect) -> CGRect {
        // Snap size to nearest grid cell count (minimum 1×1)
        let cols = max(1, round(rect.width / cellWidth))
        let rows = max(1, round(rect.height / cellHeight))
        let snappedWidth = cols * cellWidth
        let snappedHeight = rows * cellHeight

        // Snap origin to nearest grid point
        let snappedX = snapValue(rect.origin.x, to: cellWidth, base: screenFrame.origin.x)
        let snappedY = snapValue(rect.origin.y, to: cellHeight, base: screenFrame.origin.y)

        return CGRect(x: snappedX, y: snappedY, width: snappedWidth, height: snappedHeight)
    }

    /// Snap just the origin (for dragging without resizing)
    func snapOrigin(_ origin: CGPoint, size: CGSize) -> CGPoint {
        let x = snapValue(origin.x, to: cellWidth, base: screenFrame.origin.x)
        let y = snapValue(origin.y, to: cellHeight, base: screenFrame.origin.y)
        return CGPoint(x: x, y: y)
    }

    /// Snap just the size (for resizing)
    func snapSize(_ size: CGSize) -> CGSize {
        let cols = max(1, round(size.width / cellWidth))
        let rows = max(1, round(size.height / cellHeight))
        return CGSize(width: cols * cellWidth, height: rows * cellHeight)
    }

    /// Grid dimensions string (e.g. "2×3") for a given rect
    func gridLabel(for rect: CGRect) -> String {
        let cols = max(1, Int(round(rect.width / cellWidth)))
        let rows = max(1, Int(round(rect.height / cellHeight)))
        return "\(cols)×\(rows)"
    }

    /// Default rect for a new frame (2×2 centered on screen)
    func defaultFrameRect() -> CGRect {
        let w = cellWidth * 2
        let h = cellHeight * 2
        let x = screenFrame.midX - w / 2
        let y = screenFrame.midY - h / 2
        return snapRect(CGRect(x: x, y: y, width: w, height: h))
    }

    // MARK: - Private

    private func snapValue(_ value: CGFloat, to gridSize: CGFloat, base: CGFloat) -> CGFloat {
        let offset = value - base
        let snapped = round(offset / gridSize) * gridSize
        return base + snapped
    }
}
