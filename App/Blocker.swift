import Foundation
import SafariServices

/// Cardea's two Safari extensions.
enum Blocker {
    /// Content blocker: ads and trackers on every site.
    static let ads = (Bundle.main.bundleIdentifier ?? "") + ".Blocker"
    /// Web extension: ads inside YouTube videos.
    static let video = (Bundle.main.bundleIdentifier ?? "") + ".Video"

    static func adsEnabled() async -> Bool {
        await withCheckedContinuation { cont in
            SFContentBlockerManager.getStateOfContentBlocker(withIdentifier: ads) { state, _ in
                cont.resume(returning: state?.isEnabled ?? false)
            }
        }
    }

    /// nil where the platform can't tell (iOS has no API for web extensions).
    static func videoEnabled() async -> Bool? {
        #if os(macOS)
        await withCheckedContinuation { cont in
            SFSafariExtensionManager.getStateOfSafariExtension(withIdentifier: video) { state, _ in
                cont.resume(returning: state?.isEnabled ?? false)
            }
        }
        #else
        nil
        #endif
    }

    #if os(macOS)
    static func openSafariSettings(for identifier: String = ads) {
        SFSafariApplication.showPreferencesForExtension(withIdentifier: identifier)
    }
    #endif
}
