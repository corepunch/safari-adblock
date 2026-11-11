// Runs in YouTube's own JavaScript world at document_start, before the player.
// Strips the ad schedule out of every player response, so the player believes
// the video has no ads. Same technique as uBlock Origin's YouTube filters.
(() => {
  "use strict";
  if (window.__cardeaVideo) return;
  window.__cardeaVideo = true;

  const AD_KEYS = ["adPlacements", "playerAds", "adSlots", "adBreakHeartbeatParams"];
  const API = /\/youtubei\/v1\/(player|next|browse|reel\/reel_watch_sequence)\b|\/(watch|playlist)\?/;

  function prune(obj) {
    if (!obj || typeof obj !== "object") return obj;
    for (const target of [obj, obj.playerResponse]) {
      if (!target || typeof target !== "object") continue;
      for (const k of AD_KEYS) if (k in target) delete target[k];
    }
    // Shorts: drop sequence entries that are ads.
    if (Array.isArray(obj.entries)) {
      obj.entries = obj.entries.filter(e => !e?.command?.reelWatchEndpoint?.adClientParams?.isAd);
    }
    // Some responses wrap several parts (`[{playerResponse}, {response}]`).
    if (Array.isArray(obj)) obj.forEach(prune);
    return obj;
  }

  function pruneText(text) {
    if (typeof text !== "string" || !AD_KEYS.some(k => text.includes(k)) && !text.includes('"isAd"')) return text;
    try { return JSON.stringify(prune(JSON.parse(text))); } catch { return text; }
  }

  // 1. Data embedded in the HTML: `var ytInitialPlayerResponse = {...}`.
  for (const name of ["ytInitialPlayerResponse", "playerResponse"]) {
    let value;
    try {
      Object.defineProperty(window, name, {
        configurable: true,
        get: () => value,
        set: v => { value = prune(v); },
      });
    } catch {}
  }

  // 2. JSON parsed by the player (covers inline config and XHR bodies).
  const parse = JSON.parse;
  JSON.parse = function (text, reviver) {
    const out = parse.call(this, text, reviver);
    if (out && typeof out === "object" && (AD_KEYS.some(k => k in out) || out.playerResponse || out.entries)) prune(out);
    return out;
  };

  // 3. fetch() responses from the player API.
  const fetch = window.fetch;
  if (fetch) {
    window.fetch = async function (input, init) {
      const res = await fetch.call(this, input, init);
      const url = typeof input === "string" ? input : input?.url ?? "";
      if (!API.test(url)) return res;
      try {
        const text = await res.clone().text();
        const cleaned = pruneText(text);
        if (cleaned === text) return res;
        return new Response(cleaned, { status: res.status, statusText: res.statusText, headers: res.headers });
      } catch {
        return res;
      }
    };
  }

  // 4. XMLHttpRequest responses (older / mobile player paths).
  const XHR = window.XMLHttpRequest;
  if (XHR) {
    const open = XHR.prototype.open;
    XHR.prototype.open = function (method, url, ...rest) {
      this.__cardeaUrl = String(url);
      return open.call(this, method, url, ...rest);
    };
    for (const prop of ["responseText", "response"]) {
      const desc = Object.getOwnPropertyDescriptor(XHR.prototype, prop);
      if (!desc?.get) continue;
      Object.defineProperty(XHR.prototype, prop, {
        configurable: true,
        get() {
          const v = desc.get.call(this);
          if (this.readyState !== 4 || !API.test(this.__cardeaUrl || "")) return v;
          return typeof v === "string" ? pruneText(v) : (v && typeof v === "object" ? prune(v) : v);
        },
      });
    }
  }

  window.__cardeaPrune = prune; // exposed for tests
})();
