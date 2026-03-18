import AppKit

// Install our custom DocumentController before NSApplication.shared
// so it becomes the shared instance and prevents "cannot open files" alerts.
let dc = DocumentController()
NSLog("[FMP] main.swift — DocumentController created: %@", dc)
let app = NSApplication.shared
NSLog("[FMP] main.swift — NSDocumentController.shared type: %@, is ours: %d",
      String(describing: type(of: NSDocumentController.shared)),
      NSDocumentController.shared is DocumentController)
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
