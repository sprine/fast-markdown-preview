import Foundation
import AppKit

// Temporary stubs — will be replaced by real implementations

class SettingsViewController: NSViewController {
    weak var hotkeyManager: HotkeyManager?
    weak var panelController: PanelController?
    override func loadView() { view = NSView(frame: .init(x: 0, y: 0, width: 300, height: 200)) }
}

enum FinderBridge {
    static func selectedMarkdownPath() -> String? { return nil }
}
