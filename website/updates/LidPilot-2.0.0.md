<!-- sparkle-sign-warning:
IMPORTANT: This file was signed by Sparkle. Any modifications to this file requires updating signatures in appcasts that reference this file! This will involve re-running generate_appcast or sign_update.
-->
## 2.0.0

Released September 29, 2026 — build 15, including the V1.1 developer tools
and V2.0 workload scope. Agent adapters remain experimental.

- Opt-in bundled CLI with versioned JSON status, verified Start/Stop, local
  diagnostics export, reversible installation and supervised command execution.
- Configurable global shortcuts with no defaults, clearer troubleshooting,
  and an explicit choice of in-app, Homebrew or manual update ownership.
- Independent manual and workload requests, waiting grace, idle settling,
  bounded stale/unknown state, task outcomes and generation-safe cleanup.
- Minimal, reversible Codex/Claude hook adapters. Both remain experimental;
  uncorrelated Claude main-turn stop/wait events cannot end a newer turn.
- Refined native panel and Settings layout, compact task status, adaptive
  appearance and a programmatically accessible menu-bar popover.
- Concurrent command starts wait for their combined protection to settle before
  launching either workload. Stop and safety still invalidate pending requests.
- Helper protocol 2 adds same-owner lease replacement for overlapping requests;
  it retains the fixed power commands, identity checks and recovery boundary.

