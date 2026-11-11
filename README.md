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

## YouTube video ads (Cardea Video)

A content blocker can't stop YouTube video ads: they come from the same
domains as the videos. So Cardea ships a second, optional Safari extension,
**Cardea Video**, that only runs on youtube.com:

* `page.js` runs inside YouTube's page before the player starts and deletes
  the ad schedule (`adPlacements`, `playerAds`, `adSlots`) from every player
  response — inline data, `fetch` and `XMLHttpRequest` — plus ad entries in
  the Shorts feed. The player then believes the video has no ads.
* `content.js` is a safety net: if an ad still starts (e.g. one stitched into
  the stream), it mutes it, jumps to its end and presses Skip.
* `youtube.css` hides ad boxes in feeds, search and the watch page.

It asks Safari for access to youtube.com only. YouTube changes its player
often, so expect to update these files from time to time; `make test` runs
the unit tests in `tests/`. The YouTube app itself can't be touched — this
covers YouTube in Safari.

## Build & release

Open `Cardea.xcodeproj` — no extra tools needed.

1. Select the **Cardea** target › *Signing & Capabilities* and pick your team
   (do the same for **CardeaBlocker** and **CardeaVideo**). To make it stick
   across project regenerations, put your team ID in `DEVELOPMENT_TEAM` in
   `project.yml`.
2. Pick a destination — **Any iOS Device** or **Any Mac** — then
   *Product › Archive*. Archive once per platform.
3. In the Organizer: *Distribute App › App Store Connect › Upload*.

Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `project.yml`
before each release.

`project.yml` is the source of truth for the project. After changing it (or
adding/removing files), run `xcodegen` (`brew install xcodegen`); CI also
regenerates and commits `Cardea.xcodeproj` on every push.

To enable it:

* **Mac:** the app has a button that opens Safari's Extensions settings.
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
VideoExtension/      Cardea Video: Safari web extension for YouTube video ads
tests/               unit tests for the YouTube script (node --test)
rules/               local allow / cosmetic lists
scripts/             build_rules.py, make_icon.py, compile_rules.swift
project.yml          XcodeGen spec for Cardea.xcodeproj (generated, committed)
```

Blocklist data © HaGeZi, used under its license.
