import AppKit

final class SettingsViewController: NSViewController {
    weak var hotkeyManager: HotkeyManager?
    weak var panelController: PanelController?

    private var hotkeyLabel: NSTextField!
    private var themeSegment: NSSegmentedControl!
    private var defaultViewerButton: NSButton!

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 0))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
    }

    // MARK: - UI Construction

    private func buildUI() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        // -- Appearance section --
        stack.addArrangedSubview(makeSectionHeader("Appearance"))
        stack.setCustomSpacing(6, after: stack.arrangedSubviews.last!)

        let themeRow = makeFormRow(label: "Theme")
        themeSegment = NSSegmentedControl(labels: ["GitHub", "System"],
                                          trackingMode: .selectOne,
                                          target: self,
                                          action: #selector(themeChanged))
        themeSegment.segmentStyle = .automatic
        let savedTheme = UserDefaults.standard.string(forKey: "cssTheme") ?? CSSTheme.github.rawValue
        themeSegment.selectedSegment = savedTheme == CSSTheme.github.rawValue ? 0 : 1
        themeRow.addArrangedSubview(themeSegment)
        stack.addArrangedSubview(themeRow)

        stack.addArrangedSubview(makeSeparator())

        // -- Shortcut section --
        stack.addArrangedSubview(makeSectionHeader("Shortcut"))
        stack.setCustomSpacing(6, after: stack.arrangedSubviews.last!)

        let hotkeyRow = makeFormRow(label: "Toggle Preview")
        hotkeyLabel = NSTextField(labelWithString: hotkeyManager?.displayString ?? "\u{2325}\u{2318}P")
        hotkeyLabel.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        hotkeyLabel.textColor = .secondaryLabelColor
        hotkeyRow.addArrangedSubview(hotkeyLabel)
        let recordBtn = NSButton(title: "Record\u{2026}", target: self, action: #selector(recordHotkey))
        recordBtn.bezelStyle = .rounded
        recordBtn.controlSize = .small
        recordBtn.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        hotkeyRow.addArrangedSubview(recordBtn)
        stack.addArrangedSubview(hotkeyRow)

        stack.addArrangedSubview(makeSeparator())

        // -- File Handling section --
        stack.addArrangedSubview(makeSectionHeader("File Handling"))
        stack.setCustomSpacing(6, after: stack.arrangedSubviews.last!)

        let defaultRow = makeFormRow(label: "Default .md Viewer")
        defaultViewerButton = NSButton(
            title: LaunchServicesRegistrar.isDefaultViewer ? "Remove" : "Set as Default",
            target: self, action: #selector(toggleDefaultViewer))
        defaultViewerButton.bezelStyle = .rounded
        defaultViewerButton.controlSize = .small
        defaultViewerButton.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        defaultRow.addArrangedSubview(defaultViewerButton)
        stack.addArrangedSubview(defaultRow)

        stack.addArrangedSubview(makeSeparator())

        // -- Quit --
        let quitBtn = NSButton(title: "Quit Fast Markdown Preview", target: NSApp, action: #selector(NSApp.terminate(_:)))
        quitBtn.isBordered = false
        quitBtn.contentTintColor = .secondaryLabelColor
        quitBtn.font = .systemFont(ofSize: 12)
        let quitWrapper = NSStackView(views: [quitBtn])
        quitWrapper.alignment = .centerX
        quitWrapper.translatesAutoresizingMaskIntoConstraints = false
        let quitContainer = NSView()
        quitContainer.translatesAutoresizingMaskIntoConstraints = false
        quitContainer.addSubview(quitWrapper)
        NSLayoutConstraint.activate([
            quitWrapper.centerXAnchor.constraint(equalTo: quitContainer.centerXAnchor),
            quitWrapper.topAnchor.constraint(equalTo: quitContainer.topAnchor, constant: 4),
            quitWrapper.bottomAnchor.constraint(equalTo: quitContainer.bottomAnchor),
            quitContainer.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        stack.addArrangedSubview(quitContainer)
    }

    // MARK: - Layout Helpers

    private func makeSectionHeader(_ title: String) -> NSView {
        let label = NSTextField(labelWithString: title.uppercased())
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .tertiaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    private func makeFormRow(label: String) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 8
        row.edgeInsets = NSEdgeInsets(top: 4, left: 16, bottom: 4, right: 16)

        let lbl = NSTextField(labelWithString: label)
        lbl.font = .systemFont(ofSize: 13)
        lbl.textColor = .labelColor
        lbl.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(lbl)

        // Push controls to trailing edge
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow - 1, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow - 1, for: .horizontal)
        row.addArrangedSubview(spacer)

        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    private func makeSeparator() -> NSView {
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(separator)
        NSLayoutConstraint.activate([
            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            separator.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            separator.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
        ])
        return container
    }

    // MARK: - Actions

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
