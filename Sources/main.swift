import Cocoa

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = StackDockAppController()
app.delegate = delegate
app.run()
