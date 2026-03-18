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
        guard let listDesc = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject)) else { return }
        for i in 1...listDesc.numberOfItems {
            guard let itemDesc = listDesc.atIndex(i),
                  let coerced = itemDesc.coerce(toDescriptorType: typeFileURL),
                  let urlString = String(data: coerced.data, encoding: .utf8),
                  let url = URL(string: urlString)
            else { continue }
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
        guard let url = urls.first(where: { $0.pathExtension.lowercased() == "md" }) else { return }
        panelController.open(fileAt: url)
    }
}
