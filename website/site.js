'use strict';
// Progressive enhancement: the first real native preview is useful without JS.
const modes = {
  follow: {image:'follow-lid.png', copy:'Screen ready when open. Work continues when closed.', alt:'LidPilot: Follow Lid active with a one-hour session.'},
  screen: {image:'keep-screen-on.png', copy:'Your screen stays available. Your brightness controls stay yours.', alt:'LidPilot: Keep Screen On active with a one-hour session.'},
  running: {image:'keep-mac-running.png', copy:'Your Mac keeps working. The screen follows macOS policy.', alt:'LidPilot: Keep Mac Running active with a one-hour session.'}
};
const preview = document.querySelector('#product-image');
const description = document.querySelector('#mode-description');
for (const button of document.querySelectorAll('[data-mode]')) {
  button.addEventListener('click', () => {
    const mode = modes[button.dataset.mode];
    if (!mode || !preview || !description) return;
    preview.src = `assets/${mode.image}`;
    preview.alt = mode.alt;
    description.textContent = mode.copy;
    for (const other of document.querySelectorAll('[data-mode]')) other.setAttribute('aria-pressed', String(other === button));
  });
}
// Film is user-started, never audible/autoplaying on arrival. Pause when hidden.
const film = document.querySelector('#intro-film');
document.addEventListener('visibilitychange', () => { if (document.hidden && film) film.pause(); });
