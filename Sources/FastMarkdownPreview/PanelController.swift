import AppKit

final class PanelController: NSObject {
    private var panel: NSPanel!
    private(set) var webVC: WebViewController!
    private var fileWatcher: FileWatcher?

    override init() {
        super.init()
        webVC = WebViewController()
        setupPanel()
    }

    private func setupPanel() {
        let frame = savedFrame()
        panel = NSPanel(
            contentRect: frame,
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel,
                        .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true

        // Visual effect view for glass/vibrancy background
        let visualEffect = NSVisualEffectView(frame: .zero)
        visualEffect.material = .sidebar
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .followsWindowActiveState

        // Use DroppableView as content view
        let dropView = DroppableView(frame: .zero)
        dropView.registerForDraggedTypes([.fileURL])
        dropView.onDrop = { [weak self] url in
            self?.open(fileAt: url)
        }
        panel.contentView = dropView

        // Add visual effect view behind everything
        dropView.addSubview(visualEffect)
        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            visualEffect.topAnchor.constraint(equalTo: dropView.topAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: dropView.bottomAnchor),
            visualEffect.leadingAnchor.constraint(equalTo: dropView.leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: dropView.trailingAnchor),
        ])

        // Embed webVC view on top of the visual effect
        let webViewContainer = webVC.view
        dropView.addSubview(webViewContainer)
        webViewContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webViewContainer.topAnchor.constraint(equalTo: dropView.topAnchor),
            webViewContainer.bottomAnchor.constraint(equalTo: dropView.bottomAnchor),
            webViewContainer.leadingAnchor.constraint(equalTo: dropView.leadingAnchor),
            webViewContainer.trailingAnchor.constraint(equalTo: dropView.trailingAnchor),
        ])

        // Esc hides panel
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53, self?.panel.isKeyWindow == true {
                self?.panel.orderOut(nil)
                return nil
            }
            return event
        }
    }

    func open(fileAt url: URL) {
        panel.title = url.lastPathComponent
        webVC.load(markdownAt: url)
        startWatching(url: url)
        if !panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func show() {
        if !panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - File Watching

    private func startWatching(url: URL) {
        fileWatcher?.stop()
        fileWatcher = FileWatcher(path: url.path) { [weak self] event in
            DispatchQueue.main.async {
                switch event {
                case .changed:
                    self?.webVC.reload(markdownAt: url)
                case .gone:
                    self?.webVC.showFileGoneBanner()
                }
            }
        }
        fileWatcher?.start()
    }

    // MARK: - Persistence

    private func savedFrame() -> NSRect {
        if let str = UserDefaults.standard.string(forKey: "panelFrame") {
            return NSRectFromString(str)
        }
        return NSRect(x: 200, y: 200, width: 800, height: 620)
    }

    private func saveFrame() {
        UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: "panelFrame")
    }
}

// MARK: - NSWindowDelegate

extension PanelController: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        saveFrame()
        sender.orderOut(nil)
        return false
    }

    func windowDidResize(_ notification: Notification) { saveFrame() }
    func windowDidMove(_ notification: Notification) { saveFrame() }
}

// MARK: - Drag and Drop

final class DroppableView: NSView {
    var onDrop: ((URL) -> Void)?

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return hasMDFile(sender) ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = mdFileURL(from: sender) else { return false }
        onDrop?(url)
        return true
    }

    private func hasMDFile(_ sender: NSDraggingInfo) -> Bool {
        mdFileURL(from: sender) != nil
    }

    private func mdFileURL(from sender: NSDraggingInfo) -> URL? {
        let pb = sender.draggingPasteboard
        guard let urls = pb.readObjects(forClasses: [NSURL.self],
                                        options: [.urlReadingFileURLsOnly: true]) as? [URL]
        else { return nil }
        return urls.first { $0.pathExtension.lowercased() == "md" }
    }
}
