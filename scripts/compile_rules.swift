// Compiles Blocker/blockerList.json with WebKit's content rule compiler —
// the same compiler Safari runs when the extension is enabled. Fails on any
// rule Safari would reject (bad regex, unknown key, over the rule limit).
//   swift scripts/compile_rules.swift Blocker/blockerList.json
import Foundation
import WebKit

let path = CommandLine.arguments.dropFirst().first ?? "Blocker/blockerList.json"
let json = try String(contentsOfFile: path, encoding: .utf8)
let count = (try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [Any])?.count ?? -1
print("Compiling \(count) rules from \(path)…")

let start = Date()
WKContentRuleListStore.default().compileContentRuleList(
    forIdentifier: "cardea-ci", encodedContentRuleList: json
) { list, error in
    let secs = String(format: "%.2f", Date().timeIntervalSince(start))
    if let error {
        print("FAIL after \(secs)s: \(error)")
        exit(1)
    }
    print("OK: \(list!.identifier ?? "") compiled in \(secs)s")
    WKContentRuleListStore.default().removeContentRuleList(forIdentifier: "cardea-ci") { _ in exit(0) }
}
RunLoop.main.run()
