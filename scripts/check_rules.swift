// Runs Extension/rules.json through the two steps Safari performs when the
// extension is turned on: translate the declarativeNetRequest rules into
// content-blocker rules, then compile those with WebKit. Fails on anything
// Safari would reject (unsupported key, bad filter, over the rule limit).
//   swift scripts/check_rules.swift [Extension/rules.json] [--dump N]
// The translator is WebKit-internal, so it is looked up by name at run time.
import Foundation
import WebKit

var args = Array(CommandLine.arguments.dropFirst())
var dump = 0
if let i = args.firstIndex(of: "--dump") {
    dump = Int(args[i + 1]) ?? 0
    args.removeSubrange(i...(i + 1))
}
let path = args.first ?? "Extension/rules.json"
let data = try Data(contentsOf: URL(fileURLWithPath: path))
guard let rules = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
    print("FAIL: \(path) is not a JSON array of rules")
    exit(1)
}

_ = WKWebView.self   // make sure WebKit is loaded before the lookup
guard let translator = NSClassFromString("_WKWebExtensionDeclarativeNetRequestTranslator") as? NSObject.Type else {
    print("FAIL: this WebKit has no declarativeNetRequest translator")
    exit(1)
}
let selector = NSSelectorFromString("translateRules:errorStrings:")
typealias Translate = @convention(c) (AnyObject, Selector, NSDictionary, AutoreleasingUnsafeMutablePointer<NSArray?>) -> NSArray?
let translate = unsafeBitCast(translator.method(for: selector), to: Translate.self)
var errors: NSArray?
let translated = translate(translator, selector, ["rules": rules] as NSDictionary, &errors) ?? []
if let errors, errors.count > 0 {
    print("FAIL: Safari rejects \(errors.count) rule(s):")
    for e in errors.prefix(10) { print("  \(e)") }
    exit(1)
}
print("\(rules.count) declarativeNetRequest rules -> \(translated.count) content-blocker rules")
if translated.count == 0 {
    print("FAIL: nothing survived translation")
    exit(1)
}
for r in translated.prefix(dump) {
    print("  " + String(data: try JSONSerialization.data(withJSONObject: r, options: [.sortedKeys]), encoding: .utf8)!)
}

let json = String(data: try JSONSerialization.data(withJSONObject: translated), encoding: .utf8)!
let start = Date()
WKContentRuleListStore.default().compileContentRuleList(
    forIdentifier: "cardea-check", encodedContentRuleList: json
) { list, error in
    let secs = String(format: "%.2f", Date().timeIntervalSince(start))
    if let error {
        print("FAIL after \(secs)s: \(error)")
        exit(1)
    }
    print("OK: compiled in \(secs)s")
    WKContentRuleListStore.default().removeContentRuleList(forIdentifier: "cardea-check") { _ in exit(0) }
}
RunLoop.main.run()
