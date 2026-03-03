import Cocoa

// MARK: - FrameGroup Model

struct FrameGroup: Codable, Identifiable {
    let id: UUID
    var title: String
    var rect: CodableRect
    var colorIndex: Int

    init(title: String = "Untitled", rect: CGRect, colorIndex: Int = 0) {
        self.id = UUID()
        self.title = title
        self.rect = CodableRect(cgRect: rect)
        self.colorIndex = colorIndex
    }
}

// CGRect is not Codable by default, so we wrap it
struct CodableRect: Codable {
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    init(cgRect: CGRect) {
        self.x = cgRect.origin.x
        self.y = cgRect.origin.y
        self.width = cgRect.size.width
        self.height = cgRect.size.height
    }
}
