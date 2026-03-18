import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private(set) var panelController: PanelController!
    private var hotkeyManager: HotkeyManager!

    override init() {
        panelController = PanelController()
        super.init()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Register our own kAEOpenDocuments handler to completely bypass
        // NSDocumentController, which shows "cannot open files" errors
        // for non-document-based apps.
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleOpenDocuments(_:withReply:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEOpenDocuments)
        )
    }

    @objc func handleOpenDocuments(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        NSLog("[FMP] handleOpenDocuments Apple Event fired")
        guard let listDesc = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject)) else {
            NSLog("[FMP] handleOpenDocuments — no direct object in event")
            return
        }
        NSLog("[FMP] handleOpenDocuments — %d items in list", listDesc.numberOfItems)
        for i in 1...listDesc.numberOfItems {
            guard let itemDesc = listDesc.atIndex(i) else {
                NSLog("[FMP] handleOpenDocuments — item %d is nil", i)
                continue
            }
            NSLog("[FMP] handleOpenDocuments — item %d descriptorType: %u, stringValue: %@",
                  i, itemDesc.descriptorType, itemDesc.stringValue ?? "(nil)")
            guard let coerced = itemDesc.coerce(toDescriptorType: typeFileURL) else {
                NSLog("[FMP] handleOpenDocuments — coerce to typeFileURL failed for item %d", i)
                continue
            }
            let urlString = String(data: coerced.data, encoding: .utf8) ?? "(nil)"
            NSLog("[FMP] handleOpenDocuments — coerced URL string: %@", urlString)
            guard let url = URL(string: urlString) else {
                NSLog("[FMP] handleOpenDocuments — URL(string:) failed for: %@", urlString)
                continue
            }
            NSLog("[FMP] handleOpenDocuments — opening: %@", url.path)
            panelController.open(fileAt: url)
        }
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
        NSLog("[FMP] application(_:open:) called with %d URLs: %@", urls.count, urls.map(\.path).joined(separator: ", "))
        guard let url = urls.first(where: { $0.pathExtension.lowercased() == "md" }) else { return }
        panelController.open(fileAt: url)
    }
}
