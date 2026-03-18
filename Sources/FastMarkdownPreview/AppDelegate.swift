import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private(set) var panelController: PanelController!
    private var hotkeyManager: HotkeyManager!

    func applicationWillFinishLaunching(_ notification: Notification) {
        panelController = PanelController()

        // Intercept kAEOpenDocuments before NSDocumentController can handle it.
        // This prevents the "cannot open files" error for non-document-based apps.
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleOpenDocuments(_:withReply:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEOpenDocuments)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        hotkeyManager = HotkeyManager { [weak self] in
            self?.handleHotkey()
        }
        setupPopover()
    }

    @objc private func handleOpenDocuments(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        guard let listDesc = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject)) else { return }
        for i in 1...listDesc.numberOfItems {
            guard let itemDesc = listDesc.atIndex(i),
                  let urlString = itemDesc.stringValue,
                  let url = URL(string: urlString),
                  ["md", "markdown"].contains(url.pathExtension.lowercased()) else { continue }
            panelController.open(fileAt: url)
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let button = statusItem.button!
        if let img = NSImage(systemSymbolName: "doc.richtext",
                             accessibilityDescription: "Markdown Preview") {
            img.isTemplate = true
            button.image = img
        } else {
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
