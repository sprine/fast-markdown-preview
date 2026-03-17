import AppKit

final class SettingsViewController: NSViewController {
    weak var hotkeyManager: HotkeyManager?
    weak var panelController: PanelController?

    private var hotkeyLabel: NSTextField!
    private var themeSegment: NSSegmentedControl!
    private var defaultViewerButton: NSButton!

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 200))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
    }

    private func buildUI() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        // Hotkey row
        let hotkeyRow = makeRow(label: "Hotkey:")
        hotkeyLabel = NSTextField(labelWithString: hotkeyManager?.displayString ?? "\u{2325}\u{2318}P")
        hotkeyLabel.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        hotkeyRow.addArrangedSubview(hotkeyLabel)
        let recordBtn = NSButton(title: "Record\u{2026}", target: self, action: #selector(recordHotkey))
        recordBtn.bezelStyle = .rounded
        hotkeyRow.addArrangedSubview(recordBtn)
        stack.addArrangedSubview(hotkeyRow)

        // Theme row
        let themeRow = makeRow(label: "Theme:")
        themeSegment = NSSegmentedControl(labels: ["GitHub", "System"],
                                          trackingMode: .selectOne,
                                          target: self,
                                          action: #selector(themeChanged))
        let savedTheme = UserDefaults.standard.string(forKey: "cssTheme") ?? CSSTheme.github.rawValue
        themeSegment.selectedSegment = savedTheme == CSSTheme.github.rawValue ? 0 : 1
        themeRow.addArrangedSubview(themeSegment)
        stack.addArrangedSubview(themeRow)

        // Default viewer row
        let defaultRow = makeRow(label: "Default .md viewer:")
        defaultViewerButton = NSButton(
            title: LaunchServicesRegistrar.isDefaultViewer ? "Remove" : "Set as Default",
            target: self, action: #selector(toggleDefaultViewer))
        defaultViewerButton.bezelStyle = .rounded
        defaultRow.addArrangedSubview(defaultViewerButton)
        stack.addArrangedSubview(defaultRow)

        // Quit
        let quitBtn = NSButton(title: "Quit", target: NSApp, action: #selector(NSApp.terminate(_:)))
        quitBtn.bezelStyle = .rounded
        stack.addArrangedSubview(quitBtn)
    }

    private func makeRow(label: String) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        let lbl = NSTextField(labelWithString: label)
        lbl.font = .systemFont(ofSize: 13)
        lbl.setContentHuggingPriority(.required, for: .horizontal)
        row.addArrangedSubview(lbl)
        return row
    }

    @objc private func recordHotkey() {
        let alert = NSAlert()
        alert.messageText = "Press a new hotkey combination"
        alert.informativeText = "Use \u{2318}, \u{2325}, \u{2303}, \u{21E7} with a letter key."
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let field = KeyCaptureField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        let response = alert.runModal()
        if response == .alertFirstButtonReturn,
           let keyCode = field.capturedKeyCode,
           let mods = field.capturedModifiers {
            hotkeyManager?.updateHotkey(keyCode: keyCode, modifiers: mods)
            hotkeyLabel.stringValue = hotkeyManager?.displayString ?? ""
        }
    }

    @objc private func themeChanged() {
        let theme: CSSTheme = themeSegment.selectedSegment == 0 ? .github : .system
        panelController?.webVC.applyTheme(theme)
    }

    @objc private func toggleDefaultViewer() {
        if LaunchServicesRegistrar.isDefaultViewer {
            LaunchServicesRegistrar.removeAsDefaultViewer()
            defaultViewerButton.title = "Set as Default"
        } else {
            LaunchServicesRegistrar.setAsDefaultViewer()
            defaultViewerButton.title = "Remove"
        }
    }
}

// MARK: - Key Capture Field

final class KeyCaptureField: NSTextField {
    private(set) var capturedKeyCode: UInt32?
    private(set) var capturedModifiers: UInt32?

    override func keyDown(with event: NSEvent) {
        capturedKeyCode = UInt32(event.keyCode)
        var mods: UInt32 = 0
        if event.modifierFlags.contains(.command) { mods |= UInt32(cmdKey) }
        if event.modifierFlags.contains(.option)  { mods |= UInt32(optionKey) }
        if event.modifierFlags.contains(.control) { mods |= UInt32(controlKey) }
        if event.modifierFlags.contains(.shift)   { mods |= UInt32(shiftKey) }
        capturedModifiers = mods
        stringValue = describeKey(keyCode: capturedKeyCode!, modifiers: mods)
    }

    private func describeKey(keyCode: UInt32, modifiers: UInt32) -> String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("\u{2303}") }
        if modifiers & UInt32(optionKey)  != 0 { parts.append("\u{2325}") }
        if modifiers & UInt32(shiftKey)   != 0 { parts.append("\u{21E7}") }
        if modifiers & UInt32(cmdKey)     != 0 { parts.append("\u{2318}") }
        let labels: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P",
            37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
        ]
        parts.append(labels[keyCode] ?? "?")
        return parts.joined()
    }
}
