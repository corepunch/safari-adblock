# Cardea — Content Blocker for Safari

Named after the Roman goddess of doorways, who kept harmful spirits out of the home.

One switch in Safari. No "Blocklist 1–4", no "Extra", no help popovers, no
toolbar button, no account, no settings. Turn it on once and forget it exists.

Runs on **iOS / iPadOS 17+** and **macOS 14+** from a single multiplatform target.

## Why it's fast

Cardea is a pure [content blocker](https://developer.apple.com/documentation/safariservices/creating-a-content-blocker):

* The rule list is compiled **at build time** and shipped inside the extension.
  Safari compiles it to bytecode once (on install/update) and matches every
  request natively, inside WebKit. Cardea never sees your traffic, injects no
  JavaScript and runs no code while you browse.
* All ~88k domain rules share one URL prefix
  (`^[^:]+://+([^:/]+\.)?<domain>[:/]`), so WebKit folds them into a single
  automaton.
* Element hiding is **one** `css-display-none` rule with grouped selectors —
  the form Apple recommends.
* Everything fits in **one** extension (Safari allows 150,000 rules each), so
  Safari shows a single "Cardea" entry.

## Why it doesn't break things

* Domains come from **[HaGeZi Multi LIGHT](https://github.com/hagezi/dns-blocklists)** —
  ads, trackers, telemetry, built only from domains seen on Top 1M/10M lists,
  tuned to block without breaking sites.
* A top-frame `ignore-previous-rules` rule means **you can always open any
  page or follow any link** (including tracking redirects in emails). Only what
  a page *loads* — scripts, iframes, images, beacons — is blocked. This is
  what makes an allowlist UI unnecessary.
* Cosmetic selectors (`rules/cosmetic.txt`) are deliberately few and specific.

## Build

```bash
brew install xcodegen
```

```bash
make open
```

Set your team in *Signing & Capabilities* (or `DEVELOPMENT_TEAM` in
`project.yml`), pick an iOS or Mac destination, run. To enable it:

* **Mac:** the app has one button that opens Safari's Extensions settings.
* **iPhone/iPad:** Settings › Safari › Extensions › Cardea.

The app checks the state and shows a green check once it's on.

## Updating the lists

```bash
make rules
```

Re-downloads HaGeZi Multi LIGHT and rewrites `Blocker/blockerList.json`.
Ship a new build to deliver it.

* `rules/allow.txt` — domains to never block (false-positive fixes).
* `rules/cosmetic.txt` — generic element-hiding selectors (`!` starts a comment).

## Layout

```
App/                 SwiftUI app: status + one button, nothing else
Blocker/             content blocker extension + generated blockerList.json
rules/               local allow / cosmetic lists
scripts/             build_rules.py, make_icon.py
project.yml          XcodeGen spec (the .xcodeproj is generated)
```

Blocklist data © HaGeZi, used under its license.
