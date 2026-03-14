import Cocoa

// MARK: - FrameGroup Model

enum FrameBackgroundStyle: String, Codable {
    case outline
    case clear
    case solidColor
    case image
}

enum FrameBackgroundColor: String, Codable, CaseIterable {
    case white
    case black
    case gray
    case green
    case blue
    case pink

    var title: String {
        switch self {
        case .white: return "White"
        case .black: return "Black"
        case .gray: return "Gray"
        case .green: return "Green"
        case .blue: return "Blue"
        case .pink: return "Pink"
        }
    }

    var fillColor: NSColor {
        switch self {
        case .white: return NSColor(calibratedWhite: 0.98, alpha: 0.94)
        case .black: return NSColor(calibratedWhite: 0.18, alpha: 0.9)
        case .gray: return NSColor(calibratedWhite: 0.86, alpha: 0.92)
        case .green: return Self.pastelColor(.systemGreen)
        case .blue: return Self.pastelColor(.systemBlue)
        case .pink: return Self.pastelColor(.systemPink)
        }
    }

    var outlineColor: NSColor {
        switch self {
        case .white, .gray:
            return NSColor.black.withAlphaComponent(0.18)
        case .black:
            return NSColor.white.withAlphaComponent(0.3)
        case .green, .blue, .pink:
            return NSColor.white.withAlphaComponent(0.28)
        }
    }

    var titleTextColor: NSColor {
        switch self {
        case .black:
            return .white
        default:
            return .black
        }
    }

    var menuSwatchImage: NSImage {
        let size = NSSize(width: 12, height: 12)
        let image = NSImage(size: size)
        image.lockFocus()

        let swatchRect = NSRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(ovalIn: swatchRect)
        fillColor.withAlphaComponent(1).setFill()
        path.fill()

        let borderColor = (self == .white || self == .gray)
            ? NSColor.black.withAlphaComponent(0.2)
            : NSColor.white.withAlphaComponent(0.35)
        borderColor.setStroke()
        path.lineWidth = 1
        path.stroke()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func pastelColor(_ color: NSColor) -> NSColor {
        guard let blended = color.usingColorSpace(.deviceRGB)?
            .blended(withFraction: 0.72, of: NSColor.white) else {
            return color.withAlphaComponent(0.9)
        }

        return blended.withAlphaComponent(0.92)
    }

    static func decodePersistedValue(_ rawValue: String?) -> FrameBackgroundColor {
        guard let rawValue else { return .white }

        if let color = FrameBackgroundColor(rawValue: rawValue) {
            return color
        }

        switch rawValue {
        case "red", "orange", "yellow":
            return .pink
        case "purple":
            return .blue
        case "teal":
            return .green
        default:
            return .white
        }
    }

    fileprivate static func legacyColor(_ index: Int) -> FrameBackgroundColor? {
        switch index {
        case 1, 2: return .blue
        case 3, 4: return .pink
        case 5, 6: return .green
        default: return nil
        }
    }
}

struct FrameGroup: Codable, Identifiable {
    let id: UUID
    var title: String
    var rect: CodableRect
    var backgroundStyle: FrameBackgroundStyle
    var backgroundColor: FrameBackgroundColor
    var backgroundImagePath: String?

    init(
        title: String = "Untitled",
        rect: CGRect,
        backgroundStyle: FrameBackgroundStyle = .outline,
        backgroundColor: FrameBackgroundColor = .white,
        backgroundImagePath: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.rect = CodableRect(cgRect: rect)
        self.backgroundStyle = backgroundStyle
        self.backgroundColor = backgroundColor
        self.backgroundImagePath = backgroundImagePath
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case rect
        case colorIndex
        case backgroundStyle
        case backgroundColor
        case backgroundImagePath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        rect = try container.decode(CodableRect.self, forKey: .rect)

        if let style = try container.decodeIfPresent(FrameBackgroundStyle.self, forKey: .backgroundStyle) {
            backgroundStyle = style
            let rawBackgroundColor = try container.decodeIfPresent(String.self, forKey: .backgroundColor)
            backgroundColor = FrameBackgroundColor.decodePersistedValue(rawBackgroundColor)
            backgroundImagePath = try container.decodeIfPresent(String.self, forKey: .backgroundImagePath)
        } else {
            let legacyIndex = try container.decodeIfPresent(Int.self, forKey: .colorIndex) ?? 0
            backgroundImagePath = nil
            if let legacyColor = FrameBackgroundColor.legacyColor(legacyIndex) {
                backgroundStyle = .solidColor
                backgroundColor = legacyColor
            } else {
                backgroundStyle = .outline
                backgroundColor = .white
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(rect, forKey: .rect)
        try container.encode(backgroundStyle, forKey: .backgroundStyle)
        try container.encode(backgroundColor, forKey: .backgroundColor)
        try container.encodeIfPresent(backgroundImagePath, forKey: .backgroundImagePath)
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
