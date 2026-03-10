/* Substrate Arcade — Shared Game Frame
   Auto-injects the Substrate top bar into any game page.

   Usage: <script src="../shared/substrate-frame.js"></script>

   Configuration via data attributes on the script tag:
     data-title="GAME TITLE"
     data-lore="Short lore tagline"
     data-agent="AgentName"
     data-agent-color="#00e09a"
*/
(function() {
  var script = document.currentScript;
  var title = script.getAttribute('data-title') || document.title;
  var lore = script.getAttribute('data-lore') || '';
  var agent = script.getAttribute('data-agent') || '';
  var agentColor = script.getAttribute('data-agent-color') || '#00e09a';

  var bar = document.createElement('div');
  bar.className = 'substrate-bar';
  bar.innerHTML =
    '<div class="substrate-bar-left">' +
      '<a href="/arcade/" class="substrate-bar-logo">substrate</a>' +
      '<span class="substrate-bar-sep">/</span>' +
      '<span class="substrate-bar-title">' + title + '</span>' +
      (lore ? '<span class="substrate-bar-sep">&mdash;</span><span class="substrate-bar-lore">' + lore + '</span>' : '') +
    '</div>' +
    '<div class="substrate-bar-right">' +
      (agent ? '<span class="substrate-bar-agent" style="color:' + agentColor + '">' + agent + '</span>' : '') +
      '<a href="/arcade/">&larr; arcade</a>' +
    '</div>';

  // Inject bar
  document.body.insertBefore(bar, document.body.firstChild);

  // Add padding to body so game content isn't hidden behind bar
  document.body.style.paddingTop = (parseInt(getComputedStyle(document.body).paddingTop) || 0) + 36 + 'px';
})();
