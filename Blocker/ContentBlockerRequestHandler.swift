import Foundation

/// Hands Safari the precompiled rule list shipped inside the extension.
/// Safari compiles it once (on install/update) into bytecode and matches
/// natively — nothing runs per page, no JavaScript is injected.
final class ContentBlockerRequestHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        let item = NSExtensionItem()
        if let url = Bundle.main.url(forResource: "blockerList", withExtension: "json"),
           let attachment = NSItemProvider(contentsOf: url) {
            item.attachments = [attachment]
        }
        context.completeRequest(returningItems: [item], completionHandler: nil)
    }
}
