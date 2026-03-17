import AppKit

enum LaunchServicesRegistrar {
    static var isDefaultViewer: Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return false }
        let mdUTI = "net.daringfireball.markdown" as CFString
        let handler = LSCopyDefaultRoleHandlerForContentType(mdUTI, .all)?
            .takeRetainedValue() as String?
        return handler == bundleID
    }

    static func setAsDefaultViewer() {
        guard let bundleID = Bundle.main.bundleIdentifier as CFString? else { return }
        let mdUTI = "net.daringfireball.markdown" as CFString
        LSSetDefaultRoleHandlerForContentType(mdUTI, .all, bundleID)
        let plainMD = "public.markdown" as CFString
        LSSetDefaultRoleHandlerForContentType(plainMD, .all, bundleID)
    }

    static func removeAsDefaultViewer() {
        let mdUTI = "net.daringfireball.markdown" as CFString
        LSSetDefaultRoleHandlerForContentType(mdUTI, .all, "com.apple.TextEdit" as CFString)
    }
}
