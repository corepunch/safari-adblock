# Cardea — Ad Blocker for Safari

Named after the Roman goddess of doorways, who kept harmful spirits out of the home.

One switch in Safari. No "Blocklist 1–4", no "Extra", no help popovers, no
account, no settings. Turn it on once and forget it exists.

The whole product is **one Safari web extension** — the `Extension/` folder.
There is no app, no second extension and no Xcode project in this repository.

## Why there is still an "app" in the App Store

Safari has no way to install a bare extension: on both macOS and iOS an
extension is a plug-in that lives inside an app, and the App Store only
distributes apps. What changed is that you no longer have to write that app.
Upload a ZIP of the extension to App Store Connect and Apple's
[Safari Web Extension Packager](https://developer.apple.com/documentation/safariservices/packaging-and-distributing-safari-web-extensions-with-app-store-connect)
builds the wrapper for macOS and iOS (iPadOS and visionOS run the iOS one).

## How it blocks

* **Network rules** (`rules.json`, ~88k domains) are a
  `declarativeNetRequest` ruleset. Safari translates it into a content
  blocker and matches every request natively inside WebKit; no JavaScript of
  ours runs for it.
* Domains come from **[HaGeZi Multi LIGHT](https://github.com/hagezi/dns-blocklists)** —
  ads, trackers, telemetry, built only from domains seen on Top 1M/10M lists,
  tuned to block without breaking sites.
* The rules never apply to the page you open, only to what a page *loads* —
  scripts, iframes, images, beacons. So **you can always open any page or
  follow any link** (including tracking redirects in emails), which is what
  makes an allowlist UI unnecessary.
* **Cosmetic rules** (`cosmetic.css`, from `rules/cosmetic.txt`) hide the
  empty boxes blocked ads leave behind. The selectors are deliberately few and
  specific.

## YouTube video ads

Network rules can't stop YouTube video ads: they come from the same domains as
the videos. So on youtube.com the extension also runs a script:

* `page.js` runs inside YouTube's page before the player starts and deletes
  the ad schedule (`adPlacements`, `playerAds`, `adSlots`) from every player
  response — inline data, `fetch` and `XMLHttpRequest` — plus ad entries in
  the Shorts feed. The player then believes the video has no ads.
* `content.js` is a safety net: if an ad still starts (e.g. one stitched into
  the stream), it mutes it, jumps to its end and presses Skip.
* `youtube.css` hides ad boxes in feeds, search and the watch page.

YouTube changes its player often, so expect to update these files from time to
time; `make test` runs the unit tests in `tests/`. The YouTube app itself
can't be touched — this covers YouTube in Safari.

## Website access

Because it is a web extension, Safari asks the user to allow Cardea on
websites. Network blocking works either way. The cosmetic rules and the
YouTube script only work on sites where access is allowed, so the first-run
advice is **Always Allow on Every Website**. If you would rather ask for
youtube.com only, drop the first `content_scripts` entry and narrow
`host_permissions` in `Extension/manifest.json`; you lose the cosmetic rules.

`make try` shows this on a live page: it loads the extension into a WebKit
web view and reports which requests get blocked (`make try ARGS=--no-access`
for the case where access was not granted).

## Release

```bash
make zip
```

writes `Build/Cardea.zip`. In App Store Connect create the app record (macOS,
iOS or both), upload the ZIP in the Safari Web Extension Packager section,
test the build through TestFlight, then submit it. Bump `version` in
`Extension/manifest.json` before each release.

## Try it locally

```bash
make xcode
```

generates a throwaway Xcode project in `Build/xcode` that wraps the same
folder. Run it, then turn Cardea on in Safari's Extensions settings (on a Mac,
unsigned builds need *Develop › Allow Unsigned Extensions*).

The converter leaves signing and the app category empty, so `make xcode` fills
them in afterwards. Put your team ID in a `local.mk` file (git-ignored) to
have the project signed:

```
TEAM = ABCDE12345
```

## Updating the lists

```bash
make rules
```

Re-downloads HaGeZi Multi LIGHT and rewrites `Extension/rules.json` and
`Extension/cosmetic.css`. `make check` then runs the rules through the same
translator and compiler Safari uses. Ship a new build to deliver them.

* `rules/allow.txt` — domains to never block (false-positive fixes).
* `rules/cosmetic.txt` — generic element-hiding selectors (`!` starts a comment).

## Layout

```
Extension/           the extension: manifest, scripts, icons, generated rules
tests/               unit tests for the YouTube script (node --test)
rules/               local allow / cosmetic lists
scripts/             build_rules.py, check_rules.swift, try_in_webkit.swift, make_icon.py
```

Blocklist data © HaGeZi, used under its license.
