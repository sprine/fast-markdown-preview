import AppKit

/// Prevents the default NSDocumentController from showing
/// "cannot open files" alerts.  This app is not document-based;
/// file opens are routed to PanelController.
class DocumentController: NSDocumentController {

    override init() {
        super.init()
        NSLog("[FMP] DocumentController.init — shared is us: %d", NSDocumentController.shared === self)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func documentClass(forType typeName: String) -> AnyClass? {
        NSLog("[FMP] documentClass(forType: %@) → NSDocument.self", typeName)
        return NSDocument.self
    }

    override func openDocument(
        withContentsOf url: URL,
        display displayDocument: Bool,
        completionHandler: @escaping (NSDocument?, Bool, (any Error)?) -> Void
    ) {
        NSLog("[FMP] openDocument(withContentsOf: %@)", url.path)
        openInPanel(url)
        completionHandler(nil, false, nil)
    }

    override func makeDocument(
        withContentsOf url: URL,
        ofType typeName: String
    ) throws -> NSDocument {
        NSLog("[FMP] makeDocument(withContentsOf: %@, ofType: %@)", url.path, typeName)
        openInPanel(url)
        throw NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)
    }

    override func makeUntitledDocument(ofType typeName: String) throws -> NSDocument {
        NSLog("[FMP] makeUntitledDocument(ofType: %@)", typeName)
        throw NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)
    }

    private func openInPanel(_ url: URL) {
        guard let delegate = NSApp.delegate as? AppDelegate else {
            NSLog("[FMP] openInPanel FAILED — NSApp.delegate is not AppDelegate")
            return
        }
        NSLog("[FMP] openInPanel → panelController.open(%@)", url.path)
        delegate.panelController.open(fileAt: url)
    }
}
