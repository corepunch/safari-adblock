// Loads Extension/ into a real WebKit web view — the engine Safari uses — and
// reports what actually gets blocked on a live page.
//   swift scripts/try_in_webkit.swift            website access allowed
//   swift scripts/try_in_webkit.swift --no-access  website access not granted
// Needs macOS 15.4+ and a network connection.
import Foundation
import WebKit

let grantAccess = !CommandLine.arguments.contains("--no-access")
// WebKit insists on an absolute directory URL.
let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first { !$0.hasPrefix("--") } ?? "Extension",
               isDirectory: true).standardizedFileURL.absoluteURL

// Each URL is requested from the page; a blocked request fails, anything the
// network answers (whatever the status) counts as loaded.
let probe = """
const load = url => fetch(url, { mode: "no-cors", cache: "no-store" }).then(() => "loaded", () => "blocked");
const ad = document.createElement("ins");
ad.className = "adsbygoogle";
ad.textContent = "ad";
document.body.appendChild(ad);
return {
  "control (wikipedia.org)": await load("https://www.wikipedia.org/static/favicon/wikipedia.ico"),
  "ad script (pagead2.googlesyndication.com)": await load("https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js"),
  "ad server (googleads.g.doubleclick.net)": await load("https://googleads.g.doubleclick.net/pagead/id"),
  "tracker (www.google-analytics.com)": await load("https://www.google-analytics.com/analytics.js"),
  "cosmetic rule on <ins class=adsbygoogle>": getComputedStyle(ad).display === "none" ? "hidden" : "visible",
};
"""

final class Delegate: NSObject, WKNavigationDelegate {
    var done: ((String) -> Void)?
    func webView(_ v: WKWebView, didFinish n: WKNavigation!) { done?("opened") }
    func webView(_ v: WKWebView, didFail n: WKNavigation!, withError e: Error) { done?("failed: \(e.localizedDescription)") }
    func webView(_ v: WKWebView, didFailProvisionalNavigation n: WKNavigation!, withError e: Error) { done?("failed: \(e.localizedDescription)") }
}

@MainActor func open(_ view: WKWebView, _ delegate: Delegate, _ url: String) async -> String {
    await withCheckedContinuation { cont in
        delegate.done = { result in delegate.done = nil; cont.resume(returning: result) }
        view.load(URLRequest(url: URL(string: url)!))
    }
}

setvbuf(stdout, nil, _IOLBF, 0)

@MainActor func run() async throws {
    let ext = try await WKWebExtension(resourceBaseURL: root)
    for e in ext.errors { print("manifest: \(e.localizedDescription)") }
    let context = WKWebExtensionContext(for: ext)
    for p in ext.requestedPermissions { context.setPermissionStatus(.grantedExplicitly, for: p) }
    if grantAccess {
        for m in ext.allRequestedMatchPatterns { context.setPermissionStatus(.grantedExplicitly, for: m) }
    }
    context.hasAccessToPrivateData = true   // the test uses a throwaway data store
    let controller = WKWebExtensionController()
    try controller.load(context)

    let config = WKWebViewConfiguration()
    config.webExtensionController = controller
    config.websiteDataStore = .nonPersistent()
    let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 600), configuration: config)
    let delegate = Delegate()
    view.navigationDelegate = delegate

    print("\(ext.displayName ?? "?") \(ext.version ?? "?"), website access \(grantAccess ? "allowed" : "not granted")")
    try await Task.sleep(for: .seconds(15))   // Safari compiles the 88k rules in the background
    for e in context.errors { print("extension: \(e.localizedDescription)") }
    print("  open https://example.com: \(await open(view, delegate, "https://example.com/"))")
    let result = try await view.callAsyncJavaScript(probe, contentWorld: .page) as? [String: String] ?? [:]
    for (k, v) in result.sorted(by: { $0.key < $1.key }) { print("  \(k): \(v)") }
    // A blocked domain opened directly must still load: rules skip the page itself.
    print("  open https://www.google-analytics.com directly: \(await open(view, delegate, "https://www.google-analytics.com/"))")
}

Task { @MainActor in
    do { try await run(); exit(0) } catch { print("FAIL: \(error)"); exit(1) }
}
RunLoop.main.run()
