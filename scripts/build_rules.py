#!/usr/bin/env python3
"""Build the generated parts of the extension: Extension/rules.json and
Extension/cosmetic.css.

Sources:
  * HaGeZi Multi LIGHT (https://github.com/hagezi/dns-blocklists) — ads,
    trackers, telemetry. Built from domains seen on Top 1M/10M lists and
    explicitly tuned to not break sites. Already deduplicated (wildcard form).
  * rules/cosmetic.txt — a small, conservative set of generic element-hiding
    selectors so blocked ad slots don't leave empty boxes behind.
  * rules/allow.txt — domains never to block (local fixes for false positives).

rules.json is a declarativeNetRequest ruleset: one block rule per domain,
"||domain^", which matches the domain and all its subdomains. The rules name no
resource types on purpose: such a rule applies to everything a page *loads*
but never to the page itself, so you can always open any page or follow any
(tracking) link. That is what lets us ship zero "allowlist" UI.

Don't shorten this to one rule with a "requestDomains" list: Safari turns
that into a pattern with no end anchor, so "c.net" would also block
"c.network.com". scripts/check_rules.swift shows what Safari makes of it.

Usage: scripts/build_rules.py [--source FILE]   (default: download)
"""
import argparse
import json
import pathlib
import re
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
EXT = ROOT / "Extension"
RULES = EXT / "rules.json"
CSS = EXT / "cosmetic.css"
SOURCE_URL = ("https://raw.githubusercontent.com/hagezi/dns-blocklists/"
              "main/wildcard/light-onlydomains.txt")

# Safari compiles the ruleset into a content blocker, which holds at most
# 150,000 rules. Stay well under it.
SAFARI_RULE_LIMIT = 150_000
BUDGET = 140_000

DOMAIN_RE = re.compile(r"^(?=.{1,253}$)([a-z0-9_](?:[a-z0-9_-]{0,61}[a-z0-9])?\.)+[a-z][a-z0-9-]{0,62}$")


def read_list(text):
    for line in text.splitlines():
        line = line.split("#", 1)[0].strip().lower()
        if line:
            yield line


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

    if len(domains) > BUDGET:
        sys.exit(f"{len(domains)} domains exceed the {BUDGET} rule budget")
    assert len(domains) <= SAFARI_RULE_LIMIT

    rules = [{"id": i, "action": {"type": "block"}, "condition": {"urlFilter": f"||{d}^"}}
             for i, d in enumerate(domains, 1)]
    RULES.write_text(json.dumps(rules, separators=(",", ":")) + "\n")

    # One invalid selector would void a shared rule, so each gets its own.
    CSS.write_text("/* Generated from rules/cosmetic.txt by scripts/build_rules.py. */\n"
                   + "".join(f"{sel} {{ display: none !important; }}\n" for sel in selectors))

    print(f"{len(rules)} rules -> {RULES.relative_to(ROOT)} ({RULES.stat().st_size / 1e6:.1f} MB), "
          f"{len(selectors)} selectors -> {CSS.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
