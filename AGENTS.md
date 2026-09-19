Read "/Users/marios/.codex/AGENTS.md" before working in this repository.

# LidPilot repository instructions

## Workspace and authority

- Build the app in `/Users/marios/Documents/👨🏼‍💻/coding mac/LidPilot/LidPilot`.
- The requested mode is EXECUTE: plan, implement, verify, and finish the agreed V1 scope. Preserve unrelated work. Do not publish, push, merge, release, or alter production without the required explicit authority.
- Use the selected GPT-6 Astra as lead at the user's selected effort (currently Max, updated from High). Astra retains consequential planning, architecture, and design-heavy UI judgment. Prefer GPT-5.6 Luna / Max for worthwhile bounded implementation. One GPT-5.6 Sol / High may own substantial routine remaining work or final review under the global policy, without duplicate Astra review. Do not change Codex configuration or silently substitute models.
- Use CodeGraph for focused code context before edits when an index is available; confirm stale or missing information against current source. Keep the Codex progress checklist current.

## Source of truth

Read these documents before implementation and consult their relevant sections when changing behavior:

- `/Users/marios/Documents/👨🏼‍💻/coding mac/LidPilot/Planning/LidPilot_Product_Blueprint_Updated.pdf`
- `/Users/marios/Documents/👨🏼‍💻/coding mac/LidPilot/Planning/LidPilot/LidPilot_Product_Specification_Updated.md`

Planning edition 1.1 describes app V1.0; it does not authorize V1.1/V2 features. Written requirements override old concept-image wording. Concept art is inspiration, never a pixel-for-pixel implementation. The user must choose the design direction from the local HTML gallery before native UI implementation.

## Product and architecture

- Native Swift 6 / SwiftUI / AppKit, Apple Silicon only, macOS 15+. Compact menu-bar interface, settings, onboarding, accessibility, and adaptive white Soft Glass styling. No web-rendered application UI.
- Smart: arm closed-lid support while open; keep system/display awake while open; release display assertion when closed; safely reconcile on reopen. Display: app-scoped system/display assertions only. Closed: system awake, normal display policy. Off: release and verify LidPilot's controls.
- Launch and launch-at-login always start Off. Preferred mode and duration never imply activation.
- Include finite/custom/until-time/indefinite sessions, mandatory thermal protection, battery cutoff/policies, Low Power Mode and charger handling, observation, notifications, diagnostics, recovery, and Stop & Sleep.
- Separate requested, effective, and observed state. Unknown is not false. Stop and safety supersede activation; invalidate stale generations. Finite sessions and helper leases must survive delayed replies without extending their hard deadline.
- Closed-lid architecture: `LidPilot.app -> authenticated XPC -> SMAppService privileged helper -> fixed /usr/bin/pmset -a disablesleep 1/0`.
- No arbitrary commands, shell strings, sudo, osascript, client-controlled privileged paths, or general-purpose root endpoints. Authenticate both peers; use bounded execution, independently sampled safety, leases, watchdog, durable recovery journal, and independent read-back.
- Refuse a pre-existing unowned sleep override. Do not fight another controller or silently clear ambiguous state. Failed restoration remains Recovery required.
- Sparkle 2 is required for V1: pinned reviewed dependency, manual/daily checks, no silent installation, signed archives plus signed feed/notes, GitHub Releases assets and GitHub Pages appcast. Installation requires confirmed cleanup and an open lid; hold an activation barrier, coordinate helper replacement/registration, and start the updated app Off.
- No analytics, cloud accounts, AI-agent detection, CLI, process automations, Shortcuts, widgets, remote control, or Homebrew in V1.

## Validation and release boundaries

- Automated tests default to mocks; do not install/enable the helper or change this Mac's global power policy during ordinary development. Intrusive closed-lid/global-power tests require an explicit opt-in test step from the user.
- Native inactivity dimming while preventing display-off and actual internal-panel shutdown are unresolved hardware validation gates. Preserve brightness controls. No fake input, private brightness tricks, black overlays presented as panel-off, blanket external-display blanking, or unlocking.
- Do not claim that passing logic tests proves physical panel behavior, crash recovery on hardware, task continuity, safety, performance budgets, or a complete signed upgrade lifecycle.
- Build Debug and Release; run relevant automated race/recovery/protocol tests; exercise the actual `.app`; inspect native UI, accessibility, Sparkle configuration, package structure, signing where available, release scripts, and secrets before completion.
- Public release is blocked until the documented hardware, authentication, recovery, signing/notarization, update, and uninstall gates pass. Keep credentials/private keys outside source control.
- Maintain MIT license, README, CONTRIBUTING, SECURITY, CHANGELOG, architecture/safety/recovery docs, release tooling, and a simple Pages-ready site.

## History and completion

- Work on `dev` or an appropriate task branch. Make small coherent conventional commits with relevant tests; inspect each full diff before committing. No giant initial application commit or artificial commit splitting.
- Serialize Git operations between workers. Preserve unrelated staged/untracked files. Never force-push.
- Report implemented features, architecture, actual technical owner/reviewer, checks and exact revision, commits, push status, hardware gates, signing credentials still needed, and the recommended next step. Finish with a clean task tree.
- See `docs/IMPLEMENTATION_PLAN.md` for the current execution sequence. The design gallery under `design/` is a local interaction prototype, not the native app or evidence of power behavior.
