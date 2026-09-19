"use strict";

// A local design prototype only. These values never read or control macOS state.
const paths = {
  pilot: '<rect x="4" y="4" width="16" height="13" rx="2"/><path d="M2 20h20M12 8v6m-3-3 3-3 3 3"/>',
  smart: '<path d="M15.8 3.4a8.7 8.7 0 1 0 4.8 12.8 7.2 7.2 0 0 1-9-9 8 8 0 0 1 4.2-3.8Z"/><path d="m19 3 .5 1.5L21 5l-1.5.5L19 7l-.5-1.5L17 5l1.5-.5Z"/>',
  moon: '<path d="M19.8 15.4A8.3 8.3 0 0 1 8.6 4.2a8.3 8.3 0 1 0 11.2 11.2Z"/>',
  sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2m0 16v2M2 12h2m16 0h2M5 5l1.5 1.5m11 11L19 19M5 19l1.5-1.5m11-11L19 5"/>',
  display: '<rect x="3" y="4" width="18" height="13" rx="2"/><path d="M9 21h6m-3-4v4"/>',
  laptop: '<rect x="5" y="4" width="14" height="13" rx="1.5"/><path d="M2 20h20l-2-3H4Z"/>',
  closed: '<path d="M4 14h16l2 3H2l2-3Z"/><path d="M8 14v-1h8v1M3 19h18"/>',
  clock: '<circle cx="12" cy="12" r="8.5"/><path d="M12 7v5l3 2"/>',
  power: '<path d="M12 3v8m-5-5a8 8 0 1 0 10 0"/>',
  settings: '<path d="m10 3-.6 2.1-1.5.9-2.2-.5-2 3.4 1.6 1.7v1.8L3.7 14l2 3.4 2.2-.5 1.5.9L10 20h4l.6-2.2 1.5-.9 2.2.5 2-3.4-1.6-1.6v-1.8l1.6-1.7-2-3.4-2.2.5-1.5-.9L14 3Z"/><circle cx="12" cy="11.5" r="3"/>',
  more: '<circle cx="5" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/>',
  arrow: '<path d="M6 18 18 6M7 6h11v11"/>',
  right: '<path d="m9 6 6 6-6 6"/>',
  left: '<path d="m15 6-6 6 6 6"/>',
  close: '<path d="m6 6 12 12M6 18 18 6"/>',
  shield: '<path d="M12 3 4 6v6c0 4 8 9 8 9s8-5 8-9V6Z"/><path d="m8.5 11 2.5 2.5 4.5-4.5"/>',
  battery: '<rect x="2" y="7" width="18" height="10" rx="2"/><path d="M22 10v4M5 10v4m3-4v4m3-4v4m3-4v4"/>',
  wifi: '<path d="M3 8a15 15 0 0 1 18 0M6 11a10 10 0 0 1 12 0M9 14a5 5 0 0 1 6 0"/><circle cx="12" cy="17.5" r=".6"/>',
  cursor: '<path d="m5 3 14 10-7 1-3 7-4-18Z"/>',
  reset: '<path d="M4 10a8 8 0 1 1 1 8M4 4v6h6"/>',
  layers: '<path d="m12 3 10 5-10 5L2 8l10-5Zm-9 9 9 5 9-5M3 16l9 5 9-5"/>',
  bell: '<path d="M6 9a6 6 0 0 1 12 0c0 7 3 7 3 8H3c0-1 3-1 3-8Zm4 11h4"/>',
  update: '<path d="M4 10a8 8 0 1 1 1 8M4 4v6h6M12 16V8m-3 3 3-3 3 3"/>',
  check: '<path d="m5 12 4 4L19 6"/>',
  info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v6m0-10v.2"/>',
};
const icon = (name) => `<svg viewBox="0 0 24 24" aria-hidden="true">${paths[name] || paths.info}</svg>`;
const escapeHTML = (value) => String(value).replace(/[&<>"']/g, character => ({"&":"&amp;", "<":"&lt;", ">":"&gt;", '"':"&quot;", "'":"&#39;"})[character]);

const designs = [
  { id: "quiet", name: "Quiet Glass", number: "01", subtitle: "Airy, balanced, and easy to read at a glance.", headline: "A little room to breathe.", description: "One quiet control strip, a clear explanation, and an obvious action. The soft material gives the panel depth while keeping your session easy to understand.", fit: "The everyday all-rounder", hierarchy: "Mode → behaviour → duration", width: "360 pt", settings: "A familiar sidebar with softly grouped preferences.", recommended: true },
  { id: "cards", name: "Mode Cards", number: "02", subtitle: "Three equal choices, with a more visual personality.", headline: "Your modes, always in view.", description: "Each mode has its own small tile. A pale blue selection makes the current choice easy to find; nothing moves when you switch. A more visual take on the same compact utility.", fit: "Visual recognition and quick switching", hierarchy: "Mode tiles → behaviour → action", width: "360 pt", settings: "The same rounded groups, with a little more separation." },
  { id: "compact", name: "Native Compact", number: "03", subtitle: "Familiar macOS controls, with very little decoration.", headline: "Right at home in the menu bar.", description: "Tighter spacing, conventional segmented controls, and concise rows. This direction puts familiarity first and takes up the least space on your screen.", fit: "A small, traditional Mac utility", hierarchy: "Controls → concise status", width: "340 pt", settings: "Tighter rows and traditional control sizing." },
  { id: "session", name: "Session Focus", number: "04", subtitle: "A generous timer for lectures and bounded work.", headline: "Time takes the lead.", description: "The session’s end condition is the most visible detail. Mode controls stay in place above the timer, and lid behaviour stays close below it. Particularly useful for timed lectures.", fit: "Lectures and time-bounded work", hierarchy: "Mode → time → behaviour", width: "360 pt", settings: "Sessions opens first; every setting remains easy to find." },
];
const modes = {
  smart: { name: "Smart", title: "Follows your lid.", description: "Screen available when open. Mac working when closed.", open: "Mac + display kept awake", closed: "Mac awake · display follows macOS" },
  display: { name: "Display", title: "Keep your screen available.", description: "For lectures and study. Brightness stays yours.", open: "Mac + display kept awake", closed: "Normal macOS lid behaviour" },
  closed: { name: "Closed", title: "Keep your Mac running.", description: "For builds, downloads, and background work.", open: "Mac awake · display follows macOS", closed: "Mac awake · display follows macOS" },
};
const defaultUntil = () => {
  const date = new Date(Date.now() + 60 * 60 * 1000);
  date.setSeconds(0, 0);
  const local = new Date(date.getTime() - date.getTimezoneOffset() * 60000);
  return local.toISOString().slice(0, 16);
};
const state = { mode: "smart", phase: "off", lid: "open", duration: "60", customMinutes: 90, until: defaultUntil(), generation: 0 };
const preferences = { login: false, notifications: true, menuState: true, battery: false, lpm: true, automaticChecks: true, floor: "20", preferredMode: "smart", defaultDuration: "60" };
let activeDesign = 0;
let surface = "popover";
let settingsSection = "general";
let selection = null;
let startTimer;
let toastTimer;
let detailOpener = null;
const dialog = document.getElementById("detail");

function modePicker() {
  return `<div class="mode-picker" role="group" aria-label="Selected mode">${Object.entries(modes).map(([key, mode]) => `<button type="button" class="mode-button" data-mode="${key}" aria-pressed="${state.mode === key}" aria-label="${mode.name} mode">${icon(key)}<span>${mode.name}</span></button>`).join("")}</div>`;
}
function behavior() {
  const mode = modes[state.mode];
  return `<div class="behavior-card"><div class="behavior-row ${state.lid === "open" ? "current" : ""}">${icon("laptop")}<div><strong>Lid open</strong><small>${mode.open}</small></div>${state.lid === "open" ? '<span class="current-label">Now</span>' : ""}</div><div class="behavior-row ${state.lid === "closed" ? "current" : ""}">${icon("closed")}<div><strong>Lid closed</strong><small>${mode.closed}</small></div>${state.lid === "closed" ? '<span class="current-label">Now</span>' : ""}</div></div>`;
}
function durationSeconds() {
  if (state.duration === "indefinite") return null;
  if (state.duration === "until") return Math.max(0, (new Date(state.until).getTime() - Date.now()) / 1000);
  return (state.duration === "custom" ? Number(state.customMinutes) : Number(state.duration)) * 60;
}
function durationValid() {
  const seconds = durationSeconds();
  return seconds === null || (Number.isFinite(seconds) && seconds >= 60 && seconds <= 7 * 24 * 3600);
}
function durationControls() {
  const options = [["30", "30 minutes"], ["60", "1 hour"], ["120", "2 hours"], ["240", "4 hours"], ["custom", "Custom duration…"], ["until", "Until a time…"], ["indefinite", "Until I stop it"]];
  let extra = "";
  if (state.duration === "custom") extra = `<label class="duration-extra">Minutes <input class="custom-minutes" type="number" min="1" max="10080" step="1" value="${escapeHTML(state.customMinutes)}" aria-label="Custom duration in minutes"></label>`;
  if (state.duration === "until") extra = `<label class="duration-extra">Until <input class="until-time" type="datetime-local" value="${escapeHTML(state.until)}" aria-label="Session end date and time"></label>`;
  return `<div class="duration-block"><div class="duration-row"><span class="field-label">${icon("clock")}Duration</span><select class="duration-select" aria-label="Session duration">${options.map(([key, label]) => `<option value="${key}" ${state.duration === key ? "selected" : ""}>${label}</option>`).join("")}</select></div>${extra}${!durationValid() ? '<p class="settings-footnote">Choose a duration between 1 minute and 7 days.</p>' : ""}</div>`;
}
function statusCopy() {
  switch (state.phase) {
    case "starting": return ["Starting…", "Checking requested state."];
    case "active": return ["Active", state.mode === "display" ? (state.lid === "closed" ? "Native lid behaviour." : "Display assertion confirmed.") : "System flag confirmed."];
    case "paused": return ["Paused", `Battery reached the ${preferences.floor}% cutoff.`];
    case "unverified": return ["Unverified", "Could not confirm the system state."];
    case "recovery": return ["Recovery required", "Normal sleep has not been confirmed."];
    default: return ["Off", "Normal macOS behaviour."];
  }
}
function statusLine(index) {
  const [title, description] = statusCopy();
  const needsAction = ["paused", "unverified", "recovery"].includes(state.phase);
  return `<div class="status-line ${state.phase}"><span class="status-marker"></span><span class="status-text"><strong>${title}</strong> · ${description}${needsAction ? ` <button type="button" class="status-link" data-status="${index}">Details</button>` : ""}</span></div>`;
}
function primaryAction(index) {
  const stopping = ["active", "starting"].includes(state.phase);
  const recovery = ["unverified", "recovery"].includes(state.phase);
  const label = recovery ? "Review recovery" : stopping ? "Turn Off" : state.phase === "paused" ? "Review pause" : "Start session";
  return `<button type="button" class="primary-action ${stopping ? "stop" : ""}" data-primary="${index}" ${state.phase === "off" && !durationValid() ? "disabled" : ""}>${icon(recovery ? "shield" : "power")}${label}</button>`;
}
function clockFace() {
  const seconds = durationSeconds();
  let value = "∞";
  if (seconds !== null) {
    const total = Number.isFinite(seconds) ? Math.max(0, Math.round(seconds)) : 0;
    value = `${Math.floor(total / 3600)}:${String(Math.floor(total / 60) % 60).padStart(2, "0")}:${String(total % 60).padStart(2, "0")}`;
  }
  let subtitle = seconds === null ? "Until you turn it off" : "A clear end to your session";
  if (state.duration === "until" && durationValid()) subtitle = `Until ${new Date(state.until).toLocaleString([], { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" })}`;
  return `<div class="session-clock"><span class="clock-label">${state.phase === "active" ? "Remaining · preview" : "Session duration"}</span><span class="clock-time">${value}</span><span class="clock-subtitle">${escapeHTML(subtitle)}</span><div class="clock-track"><span></span></div></div>`;
}
function panel(index) {
  const design = designs[index];
  return `<div class="app-panel ${design.id}" data-design-panel="${design.id}"><header class="app-header"><div><div class="app-title">${icon("pilot")}LidPilot</div><p class="app-subtitle">Choose a mode. Set a duration.</p></div><button type="button" class="icon-button" data-settings="${index}" aria-label="Open ${design.name} settings">${icon(design.id === "compact" ? "settings" : "more")}</button></header>${modePicker()}${design.id === "session" ? clockFace() : ""}<div class="mode-copy"><h3>${modes[state.mode].title}</h3><p>${modes[state.mode].description}</p></div>${behavior()}${durationControls()}${statusLine(index)}${primaryAction(index)}${design.id === "compact" ? '<div class="compact-footer"><button type="button" data-sleep>Stop & Sleep…</button><button type="button" data-updates>Check for Updates…</button></div>' : ""}</div>`;
}
function desktop(index, expanded = false) {
  return `<div class="desktop"><div class="desktop-bar"><span class="desktop-label">${expanded ? "Menu bar preview" : "macOS · menu bar"}</span><div class="bar-tray">${icon("wifi")}${icon("battery")}<span class="bar-pilot">${icon("pilot")}</span><span>10:09</span></div></div><div class="desktop-body">${panel(index)}</div></div>`;
}
function renderGallery() {
  document.getElementById("directions").innerHTML = designs.map((design, index) => `<article class="direction" aria-labelledby="direction-${design.id}">${desktop(index)}<div class="caption"><div><div class="caption-title"><span class="caption-number">${design.number}</span><h2 id="direction-${design.id}">${design.name}</h2>${design.recommended ? '<span class="recommendation">Recommended</span>' : ""}</div><p>${design.subtitle}</p></div><button type="button" class="explore" data-explore="${index}" aria-label="Explore ${design.name}">Explore ${icon("arrow")}</button></div></article>`).join("");
  document.getElementById("preview-state").value = state.phase;
  document.getElementById("preview-lid").value = state.lid;
}
function toggle(key, title) {
  return `<button type="button" class="toggle" role="switch" aria-checked="${preferences[key]}" aria-label="${title}" data-toggle="${key}"></button>`;
}
function settingRow(title, detail, control) {
  return `<div class="settings-row"><div class="setting-label">${title}${detail ? `<small>${detail}</small>` : ""}</div>${control}</div>`;
}
function preferenceSelect(key, label, options) {
  return `<select aria-label="${label}" data-preference="${key}">${options.map(([value, text]) => `<option value="${value}" ${String(preferences[key]) === value ? "selected" : ""}>${text}</option>`).join("")}</select>`;
}
function settingsContent() {
  if (settingsSection === "sessions") return `<h3>Sessions</h3><div class="settings-group">${settingRow("Preferred mode", "Selected when the app opens.", preferenceSelect("preferredMode", "Preferred mode", [["smart","Smart"],["display","Display"],["closed","Closed"]]))}${settingRow("Default duration", "Every session starts explicitly.", preferenceSelect("defaultDuration", "Default duration", [["30","30 minutes"],["60","1 hour"],["120","2 hours"],["240","4 hours"]]))}${settingRow("Battery cutoff", "End the session while discharging.", preferenceSelect("floor", "Battery cutoff", [["10","10%"],["20","20%"],["30","30%"]]))}${settingRow("Continue on battery", "Smart and Closed after unplugging.", toggle("battery", "Continue on battery"))}</div><p class="settings-footnote">Thermal protection is always on. A safety pause never resumes automatically.</p>`;
  if (settingsSection === "protection") {
    const [title, description] = statusCopy();
    return `<h3>Protection</h3><div class="settings-group">${settingRow("Session state", description, `<span class="setting-label">${title}</span>`)}${settingRow("Helper", "Only needed for Smart and Closed.", '<span class="setting-label">Available*</span>')}${settingRow("Thermal protection", "Serious or critical → pause.", '<span class="setting-label">Always on</span>')}${settingRow("Respect Low Power Mode", "Pause Smart / Closed on battery.", toggle("lpm", "Respect Low Power Mode"))}</div><p class="settings-footnote">*Simulated helper state for this design preview. Panel shutdown and idle dimming require real-Mac validation.</p><button type="button" class="small-action" data-diagnostics>View local diagnostics</button>${["paused","unverified","recovery"].includes(state.phase) ? '<button type="button" class="small-action" data-resolve>Reset simulated issue</button>' : ""}`;
  }
  if (settingsSection === "updates") return `<h3>Updates</h3><div class="settings-group">${settingRow("Automatic update checks", "Check approximately once a day.", toggle("automaticChecks", "Automatic update checks"))}${settingRow("Installation", "End your session before updating.", '<span class="setting-label">Manual</span>')}</div><p class="settings-footnote">LidPilot uses Sparkle. Checks do not end your session. Installation waits for confirmed Off and an open lid.</p><button type="button" class="small-action" data-updates>Check for Updates…</button><p class="settings-footnote">This preview does not contact an update server.</p>`;
  return `<h3>General</h3><div class="settings-group">${settingRow("Launch at login", "Always opens Off.", toggle("login", "Launch at login"))}${settingRow("Session notifications", "When a session ends or pauses.", toggle("notifications", "Session notifications"))}${settingRow("Menu-bar status", "Show when a session is active.", toggle("menuState", "Menu-bar status"))}${settingRow("Appearance", "Adapts to your workspace.", `<select aria-label="Preview appearance" data-theme><option value="light" ${!document.body.classList.contains("dark") ? "selected" : ""}>Light</option><option value="dark" ${document.body.classList.contains("dark") ? "selected" : ""}>Dark</option></select>`)}</div><p class="settings-footnote">No accounts. No analytics. Your sessions stay on your Mac.</p>`;
}
function settingsWindow() {
  const sections = [["general","settings","General"],["sessions","clock","Sessions"],["protection","shield","Protection"],["updates","update","Updates"]];
  return `<div class="settings-stage"><div class="settings-window ${designs[activeDesign].id}-settings"><div class="settings-titlebar"><span class="traffic-lights" aria-hidden="true"><i></i><i></i><i></i></span>LidPilot Settings</div><div class="settings-layout"><nav class="settings-sidebar" aria-label="Settings sections">${sections.map(([key, symbol, name]) => `<button type="button" data-section="${key}" aria-pressed="${settingsSection === key}">${icon(symbol)}${name}</button>`).join("")}</nav><div class="settings-content">${settingsContent()}</div></div></div></div>`;
}
function designNotes() {
  const design = designs[activeDesign];
  const selected = selection === activeDesign;
  return `<aside class="design-notes"><span class="note-kicker">${surface === "settings" ? "A MATCHING SETTINGS WINDOW" : "DIRECTION " + design.number}</span><h3>${surface === "settings" ? "Everything in its place." : design.headline}</h3><p>${surface === "settings" ? design.settings + " Explore the four sections; all switches are local preview controls." : design.description}</p><dl><div><dt>Best for</dt><dd>${design.fit}</dd></div><div><dt>${surface === "settings" ? "Structure" : "Visual hierarchy"}</dt><dd>${surface === "settings" ? "General · Sessions · Protection · Updates" : design.hierarchy}</dd></div><div><dt>Native popover width</dt><dd>${design.width}</dd></div></dl><button type="button" class="choose-button" id="choose">${selected ? "✓ Your current pick" : "I like this direction"}</button><span class="choice-note" id="choice-note">${selected ? `Tell Codex: “${design.number} · ${design.name}”. You can still change your mind or combine details.` : "Mark a favourite, then tell Codex your choice."}</span></aside>`;
}
function renderDetail() {
  const design = designs[activeDesign];
  document.getElementById("detail-number").textContent = `DIRECTION ${design.number} / INTERACTIVE CONCEPT`;
  document.getElementById("detail-title").textContent = design.name;
  document.getElementById("detail-counter").textContent = `${activeDesign + 1} of ${designs.length} · simulated states`;
  document.querySelectorAll("[data-surface]").forEach(button => button.setAttribute("aria-pressed", String(button.dataset.surface === surface)));
  const body = document.getElementById("detail-body");
  body.className = `detail-body ${surface === "settings" ? "settings-body" : ""}`;
  body.innerHTML = `${surface === "settings" ? settingsWindow() : `<div class="detail-stage">${desktop(activeDesign, true)}</div>`}${designNotes()}`;
}
function render() {
  // Restore the interacted control when rebuilding the synchronized previews.
  const focused = document.activeElement;
  const panelElement = focused?.closest("[data-design-panel]");
  const focusData = focused?.dataset;
  let selector = null;
  if (focusData?.mode) selector = `[data-mode="${focusData.mode}"]`;
  else if (focused?.classList.contains("duration-select")) selector = ".duration-select";
  else if (focused?.classList.contains("custom-minutes")) selector = ".custom-minutes";
  else if (focused?.classList.contains("until-time")) selector = ".until-time";
  else if (focusData?.primary) selector = `[data-primary="${focusData.primary}"]`;
  const panelID = panelElement?.dataset.designPanel;
  const inDialog = dialog.contains(focused);
  renderGallery();
  if (dialog.open) renderDetail();
  if (selector && panelID) {
    const root = inDialog ? dialog : document.getElementById("directions");
    root.querySelector(`[data-design-panel="${panelID}"] ${selector}`)?.focus({ preventScroll: true });
  }
}
function openDetail(index, requestedSurface = "popover", section = null) {
  if (!dialog.open) detailOpener = document.activeElement;
  activeDesign = index;
  surface = requestedSurface;
  settingsSection = section || (designs[index].id === "session" ? "sessions" : "general");
  renderDetail();
  if (!dialog.open) {
    dialog.showModal();
    document.body.style.overflow = "hidden";
  }
}
function setPhase(phase) {
  clearTimeout(startTimer);
  state.generation += 1;
  state.phase = phase;
  render();
  document.getElementById("announcer").textContent = `Preview: ${statusCopy().join(". ")}`;
}
function activate(index) {
  if (["paused", "unverified", "recovery"].includes(state.phase)) return openDetail(index, "settings", "protection");
  if (["active", "starting"].includes(state.phase)) return setPhase("off");
  if (!durationValid()) return;
  setPhase("starting");
  const generation = state.generation;
  startTimer = setTimeout(() => {
    if (state.generation === generation) setPhase("active");
  }, 650);
}
function showToast(text) {
  clearTimeout(toastTimer);
  const toast = document.getElementById("toast");
  // Modal dialogs are in the top layer, so feedback belongs inside them.
  (dialog.open ? dialog : document.body).appendChild(toast);
  toast.textContent = text;
  toast.classList.add("visible");
  toastTimer = setTimeout(() => toast.classList.remove("visible"), 4000);
}
function setDark(dark) {
  document.body.classList.toggle("dark", dark);
  document.getElementById("appearance").setAttribute("aria-pressed", String(dark));
  document.getElementById("appearance-label").textContent = dark ? "Light preview" : "Dark preview";
  document.querySelector("#appearance [data-icon]").innerHTML = icon(dark ? "sun" : "moon");
  if (dialog.open) renderDetail();
}

document.querySelectorAll("[data-icon]").forEach(element => { element.innerHTML = icon(element.dataset.icon); });
document.addEventListener("click", (event) => {
  const button = event.target.closest("button");
  if (!button || button.disabled) return;
  const data = button.dataset;
  if (data.mode) { state.mode = data.mode; render(); }
  else if (data.explore !== undefined) openDetail(Number(data.explore));
  else if (data.settings !== undefined) openDetail(Number(data.settings), "settings");
  else if (data.status !== undefined) openDetail(Number(data.status), "settings", "protection");
  else if (data.primary !== undefined) activate(Number(data.primary));
  else if (data.surface) { surface = data.surface; renderDetail(); }
  else if (data.section) { settingsSection = data.section; renderDetail(); dialog.querySelector(`[data-section="${settingsSection}"]`)?.focus({ preventScroll: true }); }
  else if (data.toggle) { preferences[data.toggle] = !preferences[data.toggle]; button.setAttribute("aria-checked", String(preferences[data.toggle])); }
  else if ("sleep" in data) { setPhase("off"); showToast("Preview: controls released, then sleep requested. Your Mac stays unchanged."); }
  else if ("updates" in data) showToast("Preview only. The native app will use Sparkle’s update window.");
  else if ("diagnostics" in data) showToast("Preview: local state, last checks, and recovery events. No hardware readings here.");
  else if ("resolve" in data) { setPhase("off"); showToast("Simulated issue reset. A real recovery must be independently verified."); }
  else if (button.id === "choose") {
    selection = activeDesign;
    button.textContent = "✓ Your current pick";
    const design = designs[activeDesign];
    document.getElementById("choice-note").textContent = `Tell Codex: “${design.number} · ${design.name}”. You can still combine details from other directions.`;
  }
});
document.addEventListener("input", event => {
  const target = event.target;
  const custom = target.classList.contains("custom-minutes");
  const until = target.classList.contains("until-time");
  if (!custom && !until) return;
  if (custom) state.customMinutes = target.value;
  else state.until = target.value;
  // Preserve the field and caret while synchronizing the other previews.
  document.querySelectorAll(custom ? ".custom-minutes" : ".until-time").forEach(input => {
    if (input !== target) input.value = target.value;
  });
  document.querySelectorAll(".session-clock").forEach(clock => { clock.outerHTML = clockFace(); });
  document.querySelectorAll("[data-primary]").forEach(button => { button.disabled = state.phase === "off" && !durationValid(); });
});
document.addEventListener("change", event => {
  const target = event.target;
  if (target.classList.contains("duration-select")) { state.duration = target.value; render(); }
  else if (target.classList.contains("custom-minutes")) { state.customMinutes = target.value; render(); }
  else if (target.classList.contains("until-time")) { state.until = target.value; render(); }
  else if (target.dataset.preference) preferences[target.dataset.preference] = target.value;
  else if (target.hasAttribute("data-theme")) setDark(target.value === "dark");
});
document.getElementById("preview-state").addEventListener("change", event => setPhase(event.target.value));
document.getElementById("preview-lid").addEventListener("change", event => { state.lid = event.target.value; render(); });
document.getElementById("appearance").addEventListener("click", () => setDark(!document.body.classList.contains("dark")));
document.getElementById("reset").addEventListener("click", () => {
  Object.assign(state, { mode: "smart", lid: "open", duration: "60", customMinutes: 90, until: defaultUntil() });
  setPhase("off");
});
document.querySelector(".close-detail").addEventListener("click", () => dialog.close());
dialog.addEventListener("close", () => {
  document.body.style.overflow = "";
  document.body.appendChild(document.getElementById("toast"));
  // Gallery controls may have been recreated by a synchronized preview action.
  if (detailOpener?.isConnected) detailOpener.focus({ preventScroll: true });
  else document.querySelector(`[data-explore="${activeDesign}"]`)?.focus({ preventScroll: true });
});
dialog.addEventListener("click", event => { if (event.target === dialog) dialog.close(); });
document.getElementById("previous").addEventListener("click", () => { activeDesign = (activeDesign + designs.length - 1) % designs.length; renderDetail(); });
document.getElementById("next").addEventListener("click", () => { activeDesign = (activeDesign + 1) % designs.length; renderDetail(); });
renderGallery();
