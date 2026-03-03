# Frame It

A native macOS menu-bar app that creates translucent, frosted-glass frames on the desktop to visually group and organize your icons.

![macOS](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)

## Features

- **Glassy Frames** — Apple-style frosted glass (`NSVisualEffectView`) overlay frames on your desktop
- **Draw to Create** — Click "New Frame" in the menu bar, then drag on the desktop to create a frame
- **Drag & Resize** — Move and resize frames with intuitive handles
- **Color Palettes** — 7 accent colors (Clear, Blue, Purple, Pink, Orange, Green, Teal)
- **Rename** — Double-click the title or right-click → Rename
- **Persistent** — Frame layouts are saved to `~/Library/Application Support/FrameIt/frames.json`
- **Menu Bar Agent** — No Dock icon clutter; controls live in the menu bar
- **Multi-Space** — Frames appear across all macOS Spaces

## Build

```bash
swift build --scratch-path /tmp/frameit-build
```

> **Note:** The `--scratch-path` flag avoids an SPM build-database issue with special characters in the project directory name.

## Run

```bash
.build/debug/FrameIt
# Or with the custom scratch path:
/tmp/frameit-build/debug/FrameIt
```

## Usage

| Action | How |
|---|---|
| Create a frame | Menu bar icon → **New Frame** → drag on desktop |
| Move a frame | Menu bar → **Edit Frames** → drag the frame |
| Resize a frame | In edit mode, drag any edge or corner |
| Rename | Double-click the title, or right-click → Rename |
| Change color | Right-click frame → Color → pick one |
| Delete a frame | Right-click frame → Delete |
| Lock frames | Menu bar → **Lock Frames** |
| Quit | Menu bar → **Quit Frame It** |

## Project Structure

```
Sources/FrameIt/
├── main.swift                  # App entry point
├── AppDelegate.swift           # Wires up overlay + menu bar
├── Models/
│   ├── FrameGroup.swift        # Data model (Codable)
│   └── FrameStore.swift        # JSON persistence
├── Windows/
│   └── DesktopOverlayWindow.swift  # Transparent desktop-level window
├── Views/
│   ├── DesktopOverlayView.swift    # Root view + draw-to-create
│   └── GlassFrameView.swift        # Frosted glass frame UI
└── Controllers/
    └── MenuBarController.swift     # Status bar menu
```

## License

MIT
