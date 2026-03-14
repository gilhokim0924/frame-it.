import Cocoa

// MARK: - DesktopGrid
// Reads macOS Finder desktop icon settings and snaps frames to that grid.

struct DesktopGrid {
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let screenFrame: CGRect

    init(screen: NSScreen? = NSScreen.main) {
        screenFrame = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)

        let defaults = UserDefaults(suiteName: "com.apple.finder")
        let desktopSettings = defaults?.dictionary(forKey: "DesktopViewSettings") as? [String: Any]
        let iconSettings = desktopSettings?["IconViewSettings"] as? [String: Any]

        let iconSize = (iconSettings?["iconSize"] as? CGFloat) ?? 64
        let gridSpacing = (iconSettings?["gridSpacing"] as? CGFloat) ?? 54
        let cellSize = iconSize + gridSpacing

        cellWidth = cellSize
        cellHeight = cellSize
    }

    func snapRect(_ rect: CGRect) -> CGRect {
        let cols = max(1, round(rect.width / cellWidth))
        let rows = max(1, round(rect.height / cellHeight))
        let snappedWidth = min(cols * cellWidth, screenFrame.width)
        let snappedHeight = min(rows * cellHeight, screenFrame.height)

        var snappedX = snapValue(rect.origin.x, to: cellWidth, base: screenFrame.minX)
        let topAlignedY = snapValue(rect.maxY, to: cellHeight, base: screenFrame.maxY)
        var snappedY = topAlignedY - snappedHeight

        snappedX = max(screenFrame.minX, min(snappedX, screenFrame.maxX - snappedWidth))
        snappedY = max(screenFrame.minY, min(snappedY, screenFrame.maxY - snappedHeight))

        return CGRect(x: snappedX, y: snappedY, width: snappedWidth, height: snappedHeight)
    }

    private func snapValue(_ value: CGFloat, to gridSize: CGFloat, base: CGFloat) -> CGFloat {
        let offset = value - base
        return base + (round(offset / gridSize) * gridSize)
    }
}
