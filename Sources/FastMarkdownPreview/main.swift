import AppKit

// Install custom document controller BEFORE NSApplication.shared
// so it becomes the shared instance instead of the default one.
let docController = DocumentController()
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
NSLog("[FMP] DocumentController is shared: %d", docController === NSDocumentController.shared)
app.run()
