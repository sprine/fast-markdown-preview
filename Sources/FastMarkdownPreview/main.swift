import AppKit

// Install our custom DocumentController before NSApplication.shared
// so it becomes the shared instance and prevents "cannot open files" alerts.
let _ = DocumentController()
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
