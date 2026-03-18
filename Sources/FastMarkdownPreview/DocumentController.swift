import AppKit

/// Prevents the default NSDocumentController from showing
/// "cannot open files" alerts.  This app is not document-based;
/// file opens are handled by AppDelegate.application(_:open:).
final class DocumentController: NSDocumentController {
    override func openDocument(
        withContentsOf url: URL,
        display displayDocument: Bool,
        completionHandler: @escaping (NSDocument?, Bool, (any Error)?) -> Void
    ) {
        // Forward to the app delegate instead of trying to create an NSDocument.
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.panelController.open(fileAt: url)
        }
        completionHandler(nil, false, nil)
    }
}
