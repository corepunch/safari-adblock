import Foundation
import SafariServices

enum Blocker {
    /// Bundle identifier of the content blocker extension (app id + ".Blocker").
    static let identifier = (Bundle.main.bundleIdentifier ?? "") + ".Blocker"

    static func isEnabled() async -> Bool {
        await withCheckedContinuation { cont in
            SFContentBlockerManager.getStateOfContentBlocker(withIdentifier: identifier) { state, _ in
                cont.resume(returning: state?.isEnabled ?? false)
            }
        }
    }

    #if os(macOS)
    static func openSafariSettings() {
        SFSafariApplication.showPreferencesForExtension(withIdentifier: identifier)
    }
    #endif
}
