// Registers page.js in YouTube's own JavaScript world. Safari (16.4+)
// supports world: "MAIN" for dynamically registered scripts; the static
// manifest key is not guaranteed, so we register here.
const SCRIPT = {
  id: "cardea-video-page",
  matches: ["*://*.youtube.com/*", "*://youtube.com/*", "*://*.youtube-nocookie.com/*"],
  js: ["page.js"],
  runAt: "document_start",
  allFrames: true,
  world: "MAIN",
};

async function ensureRegistered() {
  const existing = await browser.scripting.getRegisteredContentScripts({ ids: [SCRIPT.id] });
  if (existing.length) await browser.scripting.updateContentScripts([SCRIPT]);
  else await browser.scripting.registerContentScripts([SCRIPT]);
}

browser.runtime.onInstalled.addListener(ensureRegistered);
browser.runtime.onStartup.addListener(ensureRegistered);
ensureRegistered().catch(() => {});
