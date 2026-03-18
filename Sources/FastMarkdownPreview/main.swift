import AppKit

// Install our custom DocumentController before NSApplication.shared
// so it becomes the shared instance and prevents "cannot open files" alerts.
let _ = DocumentController()
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Register kAEOpenDocuments handler BEFORE app.run() to guarantee we
// preempt NSDocumentController's handler for file-open Apple Events.
NSAppleEventManager.shared().setEventHandler(
    delegate,
    andSelector: #selector(AppDelegate.handleOpenDocuments(_:withReply:)),
    forEventClass: AEEventClass(kCoreEventClass),
    andEventID: AEEventID(kAEOpenDocuments)
)

app.run()
