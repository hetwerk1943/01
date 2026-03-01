/**
 * ads.js – SAFE AdSense module with ON/OFF toggle
 *
 * Usage:
 *   1. Add <div class="ad-slot"> where you want banners.
 *   2. Add <button id="adsToggleBtn"> to let users toggle ads.
 *   3. Include this script: <script src="ads.js"></script>
 *
 * To activate real AdSense, set ADS_ENABLED = true and fill in
 * AD_CLIENT (your ca-pub-XXXXXXXXXXXXXXXXX) and AD_SLOT IDs.
 */
(function () {
  'use strict';

  /* ── Configuration ──────────────────────────────────────────── */
  var ADS_ENABLED = false;                     // default: OFF (SAFE mode)
  var AD_CLIENT   = 'ca-pub-XXXXXXXXXXXXXXXXX'; // TODO: replace with publisher ID
  var AD_SLOT     = 'XXXXXXXXXX';               // TODO: replace with ad-slot ID

  /* ── Inject shared styles ───────────────────────────────────── */
  var style = document.createElement('style');
  style.textContent =
    '.ad-slot{width:100%;text-align:center;margin:0.75rem 0;}' +
    '.ad-placeholder{display:inline-block;background:#f6f8fa;border:1px dashed #d1d5da;' +
    'border-radius:4px;padding:0.5rem 1rem;font-size:0.75rem;color:#8b949e;' +
    'max-width:728px;width:100%;box-sizing:border-box;}' +
    '@media(max-width:480px){.ad-placeholder{max-width:100%;}}';
  document.head.appendChild(style);

  /* ── Internal helpers ───────────────────────────────────────── */
  function setSlotVisibility(enabled) {
    document.querySelectorAll('.ad-slot').forEach(function (slot) {
      slot.hidden = !enabled;
    });
  }

  function renderAdSense(slot) {
    /* Replace placeholder with real AdSense tag once AD_CLIENT is set. */
    if (AD_CLIENT.indexOf('XXXXX') === -1) {
      slot.innerHTML =
        '<ins class="adsbygoogle"' +
        ' style="display:block;width:100%;max-width:728px;margin:0 auto"' +
        ' data-ad-client="' + AD_CLIENT + '"' +
        ' data-ad-slot="' + AD_SLOT + '"' +
        ' data-ad-format="auto"' +
        ' data-full-width-responsive="true"></ins>';
      try { (window.adsbygoogle = window.adsbygoogle || []).push({}); } catch (e) { /* noop */ }
    }
  }

  function updateToggleBtn() {
    var btn = document.getElementById('adsToggleBtn');
    if (btn) btn.textContent = 'Ads: ' + (ADS_ENABLED ? 'ON \u2705' : 'OFF \u26d4');
  }

  /* ── Public toggle ──────────────────────────────────────────── */
  function toggleAds() {
    ADS_ENABLED = !ADS_ENABLED;
    if (ADS_ENABLED) {
      document.querySelectorAll('.ad-slot:not([data-adsense-loaded])').forEach(function (slot) {
        renderAdSense(slot);
        slot.setAttribute('data-adsense-loaded', '1');
      });
    }
    setSlotVisibility(ADS_ENABLED);
    updateToggleBtn();
  }

  /* ── Init ───────────────────────────────────────────────────── */
  document.addEventListener('DOMContentLoaded', function () {
    setSlotVisibility(ADS_ENABLED);
    updateToggleBtn();
    var btn = document.getElementById('adsToggleBtn');
    if (btn) btn.addEventListener('click', toggleAds);
  });

  /* ── Expose API ─────────────────────────────────────────────── */
  window.adsModule = {
    toggle: toggleAds,
    isEnabled: function () { return ADS_ENABLED; }
  };
}());
