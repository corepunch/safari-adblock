// Tests VideoExtension/Resources/page.js against fake YouTube responses.
//   node --test tests/
const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const SRC = fs.readFileSync(path.join(__dirname, "../VideoExtension/Resources/page.js"), "utf8");

const playerResponse = () => ({
  videoDetails: { videoId: "abc" },
  streamingData: { formats: [1] },
  adPlacements: [{ adPlacementRenderer: {} }],
  playerAds: [{ playerLegacyDesktopWatchAdsRenderer: {} }],
  adSlots: [{ adSlotRenderer: {} }],
});

function load(fetchBody) {
  class FakeXHR {
    open(m, url) { this.url = url; }
    get responseText() { return fetchBody; }
    get response() { return fetchBody; }
  }
  const ctx = {
    JSON, Response, Promise,
    fetch: async () => new Response(fetchBody, { status: 200 }),
    XMLHttpRequest: FakeXHR,
  };
  ctx.window = ctx;
  vm.createContext(ctx);
  vm.runInContext(SRC, ctx);
  return ctx;
}

test("strips ad keys from inline ytInitialPlayerResponse", () => {
  const w = load("");
  vm.runInContext("var ytInitialPlayerResponse = " + JSON.stringify(playerResponse()), w);
  const r = w.ytInitialPlayerResponse;
  assert.equal(r.videoDetails.videoId, "abc");
  assert.equal(r.streamingData.formats.length, 1);
  for (const k of ["adPlacements", "playerAds", "adSlots"]) assert.ok(!(k in r), k);
});

test("strips ad keys from JSON.parse results, including nested playerResponse", () => {
  const w = load("");
  const r = w.JSON.parse(JSON.stringify({ playerResponse: playerResponse(), response: {} }));
  assert.ok(!("adPlacements" in r.playerResponse));
  assert.equal(r.playerResponse.videoDetails.videoId, "abc");
});

test("leaves unrelated JSON untouched", () => {
  const w = load("");
  const src = { a: 1, entries: [{ x: 1 }] };
  assert.deepStrictEqual(w.JSON.parse(JSON.stringify(src)), src);
});

test("cleans fetch() responses from the player API", async () => {
  const w = load(JSON.stringify(playerResponse()));
  const res = await w.fetch("https://www.youtube.com/youtubei/v1/player?key=x", {});
  const body = JSON.parse(await res.text());
  assert.ok(!("playerAds" in body));
  assert.equal(body.videoDetails.videoId, "abc");
});

test("does not touch fetch() for other URLs", async () => {
  const raw = JSON.stringify(playerResponse());
  const w = load(raw);
  const res = await w.fetch("https://www.youtube.com/api/stats/qoe", {});
  assert.equal(await res.text(), raw);
});

test("removes ad entries from the Shorts sequence", async () => {
  const seq = { entries: [
    { command: { reelWatchEndpoint: { videoId: "a" } } },
    { command: { reelWatchEndpoint: { videoId: "ad", adClientParams: { isAd: true } } } },
    { command: { reelWatchEndpoint: { videoId: "b" } } },
  ] };
  const w = load(JSON.stringify(seq));
  const res = await w.fetch("https://www.youtube.com/youtubei/v1/reel/reel_watch_sequence?x", {});
  const ids = JSON.parse(await res.text()).entries.map(e => e.command.reelWatchEndpoint.videoId);
  assert.deepStrictEqual(ids, ["a", "b"]);
});

test("cleans XMLHttpRequest responses from the player API", () => {
  const w = load(JSON.stringify(playerResponse()));
  const xhr = new w.XMLHttpRequest();
  xhr.open("POST", "/youtubei/v1/player");
  Object.defineProperty(xhr, "readyState", { value: 4 });
  assert.ok(!JSON.parse(xhr.responseText).adSlots);
});

test("is idempotent when injected twice", () => {
  const w = load("");
  vm.runInContext(SRC, w);
  vm.runInContext("var ytInitialPlayerResponse = " + JSON.stringify(playerResponse()), w);
  assert.ok(!("adPlacements" in w.ytInitialPlayerResponse));
});
