import Cocoa

// Entry point — bootstrap the NSApplication with our AppDelegate.

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Agent app: activate without needing a Dock icon
app.setActivationPolicy(.accessory)

app.run()
