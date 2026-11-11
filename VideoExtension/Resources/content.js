// Safety net, in the extension's isolated world: if an ad still starts
// (e.g. one stitched into the stream), mute it, skip to its end and press
// "Skip". Runs only while the player is marked as showing an ad.
(() => {
  "use strict";
  const SKIP = ".ytp-skip-ad-button, .ytp-ad-skip-button, .ytp-ad-skip-button-modern, .ytp-ad-overlay-close-button";

  function handle(player) {
    if (!player.classList.contains("ad-showing")) return;
    const video = player.querySelector("video");
    if (video) {
      video.muted = true;
      if (Number.isFinite(video.duration) && video.duration > 0) video.currentTime = video.duration;
    }
    player.querySelectorAll(SKIP).forEach(b => b.click());
  }

  const watched = new WeakSet();
  function watch() {
    document.querySelectorAll(".html5-video-player").forEach(player => {
      if (watched.has(player)) return;
      watched.add(player);
      new MutationObserver(() => handle(player)).observe(player, { attributes: true, attributeFilter: ["class"] });
      handle(player);
    });
  }

  new MutationObserver(watch).observe(document.documentElement, { childList: true, subtree: true });
  watch();
})();
