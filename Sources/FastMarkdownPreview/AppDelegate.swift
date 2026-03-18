import AppKit

/// Prevents NSDocumentController from trying to create NSDocument instances
/// for file-open events. Instead, forwards opens to the app delegate.
class DocumentController: NSDocumentController {
    override func openDocument(withContentsOf url: URL,
                               display displayDocument: Bool,
                               completionHandler: @escaping (NSDocument?, Bool, (any Error)?) -> Void) {
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.panelController.open(fileAt: url)
        }
        completionHandler(nil, false, nil)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private(set) var panelController: PanelController!
    private var hotkeyManager: HotkeyManager!

    func applicationWillFinishLaunching(_ notification: Notification) {
        panelController = PanelController()
        // Must be installed before any file-open events arrive
        _ = DocumentController()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        hotkeyManager = HotkeyManager { [weak self] in
            self?.handleHotkey()
        }
        setupPopover()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let button = statusItem.button!
        if let img = NSImage(systemSymbolName: "doc.richtext",
                             accessibilityDescription: "Markdown Preview") {
            img.isTemplate = true
            button.image = img
        } else {
            // SF Symbol unavailable – fall back to text
            button.title = "MD"
        }
        button.action = #selector(togglePopover(_:))
        button.target = self
    }

    private func setupPopover() {
        popover = NSPopover()
        let settingsVC = SettingsViewController()
        settingsVC.hotkeyManager = hotkeyManager
        settingsVC.panelController = panelController
        popover.contentViewController = settingsVC
        popover.behavior = .transient
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func handleHotkey() {
        guard let path = FinderBridge.selectedMarkdownPath() else { return }
        panelController.open(fileAt: URL(fileURLWithPath: path))
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first(where: { $0.pathExtension.lowercased() == "md" }) else { return }
        panelController.open(fileAt: url)
    }
}
