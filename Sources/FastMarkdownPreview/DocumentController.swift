import AppKit

/// Prevents the default NSDocumentController from showing
/// "cannot open files" alerts.  This app is not document-based;
/// file opens are routed to PanelController.
class DocumentController: NSDocumentController {

    // Return NSDocument.self so NSDocumentController thinks the type is
    // handled and proceeds to openDocument / makeDocument instead of
    // showing the "cannot open files" error dialog.
    override func documentClass(forType typeName: String) -> AnyClass? {
        return NSDocument.self
    }

    override func openDocument(
        withContentsOf url: URL,
        display displayDocument: Bool,
        completionHandler: @escaping (NSDocument?, Bool, (any Error)?) -> Void
    ) {
        openInPanel(url)
        completionHandler(nil, false, nil)
    }

    override func makeDocument(
        withContentsOf url: URL,
        ofType typeName: String
    ) throws -> NSDocument {
        openInPanel(url)
        throw NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)
    }

    override func makeUntitledDocument(ofType typeName: String) throws -> NSDocument {
        throw NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)
    }

    private func openInPanel(_ url: URL) {
        guard let delegate = NSApp.delegate as? AppDelegate else { return }
        delegate.panelController.open(fileAt: url)
    }
}
