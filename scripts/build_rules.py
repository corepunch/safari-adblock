#!/usr/bin/env python3
"""Build Blocker/blockerList.json — the one and only Safari content blocker.

Sources:
  * HaGeZi Multi LIGHT (https://github.com/hagezi/dns-blocklists) — ads,
    trackers, telemetry. Built from domains seen on Top 1M/10M lists and
    explicitly tuned to not break sites. Already deduplicated (wildcard form).
  * rules/cosmetic.txt — a small, conservative set of generic element-hiding
    selectors so blocked ad slots don't leave empty boxes behind.
  * rules/allow.txt — domains never to block (local fixes for false positives).

Rule layout (order matters in Safari):
  1. block       — one rule per domain, matches the domain and all subdomains.
  2. ignore-previous-rules for top-frame documents — you can always open any
     page or follow any (tracking) link; only the things a page *loads* get
     blocked. This is what lets us ship zero "allowlist" UI.
  3. allow.txt   — ignore-previous-rules for specific domains.
  4. css-display-none — after (2), so it isn't cancelled for every page.

Usage: scripts/build_rules.py [--source FILE]   (default: download)
"""
import argparse
import json
import pathlib
import re
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "Blocker" / "blockerList.json"
SOURCE_URL = ("https://raw.githubusercontent.com/hagezi/dns-blocklists/"
              "main/wildcard/light-onlydomains.txt")

# Safari's per-content-blocker limit (Safari 15+ / iOS 15+). Stay well under it.
SAFARI_RULE_LIMIT = 150_000
BUDGET = 140_000

DOMAIN_RE = re.compile(r"^(?=.{1,253}$)([a-z0-9_](?:[a-z0-9_-]{0,61}[a-z0-9])?\.)+[a-z][a-z0-9-]{0,62}$")
# Scheme, optional subdomains, the domain, then port or path. Every rule shares
# the same prefix, which WebKit's compiler merges into one automaton.
URL_PREFIX = r"^[^:]+://+([^:/]+\.)?"
URL_SUFFIX = r"[:/]"


def read_list(text):
    for line in text.splitlines():
        line = line.split("#", 1)[0].strip().lower()
        if line:
            yield line


def url_filter(domain):
    return URL_PREFIX + re.escape(domain).replace(r"\-", "-") + URL_SUFFIX


def collapse(domains):
    """Drop entries already covered by a parent domain in the set."""
    s = set(domains)
    out = []
    for d in sorted(s):
        parts = d.split(".")
        if not any(".".join(parts[i:]) in s for i in range(1, len(parts) - 1)):
            out.append(d)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", help="local copy of the domain list")
    args = ap.parse_args()

    if args.source:
        text = pathlib.Path(args.source).read_text()
    else:
        req = urllib.request.Request(SOURCE_URL, headers={"User-Agent": "safari-adblock-build"})
        with urllib.request.urlopen(req, timeout=60) as r:
            text = r.read().decode()

    allow = set(read_list((ROOT / "rules" / "allow.txt").read_text()))
    # CSS is case-sensitive, so don't run cosmetic.txt through read_list().
    selectors = [l.strip() for l in (ROOT / "rules" / "cosmetic.txt").read_text().splitlines()
                 if l.strip() and not l.lstrip().startswith("!")]

    domains = [d for d in read_list(text) if DOMAIN_RE.match(d)]
    domains = [d for d in collapse(domains)
               if d not in allow and not any(d.endswith("." + a) for a in allow)]

    fixed = 1 + len(allow) + (1 if selectors else 0)
    if len(domains) + fixed > BUDGET:
        sys.exit(f"{len(domains)} domains exceed the {BUDGET} rule budget")

    rules = [{"trigger": {"url-filter": url_filter(d)}, "action": {"type": "block"}}
             for d in domains]
    rules.append({
        "trigger": {"url-filter": ".*", "resource-type": ["document"], "load-context": ["top-frame"]},
        "action": {"type": "ignore-previous-rules"},
    })
    for d in sorted(allow):
        rules.append({"trigger": {"url-filter": ".*", "if-domain": ["*" + d]},
                      "action": {"type": "ignore-previous-rules"}})
    if selectors:
        rules.append({"trigger": {"url-filter": ".*"},
                      "action": {"type": "css-display-none", "selector": ", ".join(selectors)}})

    assert len(rules) <= SAFARI_RULE_LIMIT
    OUT.write_text(json.dumps(rules, separators=(",", ":")) + "\n")
    print(f"{len(rules)} rules ({len(domains)} domains, {len(selectors)} selectors) "
          f"-> {OUT.relative_to(ROOT)} ({OUT.stat().st_size / 1e6:.1f} MB)")


if __name__ == "__main__":
    main()
