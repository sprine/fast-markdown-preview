import AppKit

enum FinderBridge {
    static func selectedMarkdownPath() -> String? {
        let script = """
        tell application "Finder"
            set sel to selection
            if sel is {} then return ""
            set theItem to item 1 of sel
            if class of theItem is document file or class of theItem is file then
                set ext to name extension of theItem
                if ext is "md" or ext is "markdown" then
                    return POSIX path of (theItem as alias)
                end if
            end if
            return ""
        end tell
        """
        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)!
        let result = appleScript.executeAndReturnError(&error)
        if error != nil { return nil }
        let path = result.stringValue ?? ""
        return path.isEmpty ? nil : path
    }
}
