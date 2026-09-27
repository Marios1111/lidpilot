# Homebrew launch preparation — September 27, 2026

This is tooling and local presentation evidence, not a published Homebrew
installation or a stable-release pass.

- `12870ac`: stable-only cask generator and disposable fixture checks. Exact
  repository, immutable versioned GitHub URLs, manifest metadata, and local DMG
  SHA-256 are checked. RC/profile/unapproved manifests and changed bytes are
  rejected. No privileged Homebrew hooks or signing bypasses are emitted.
- `8fd7ff4`: fixture checks included in ordinary verification and CI.
- `434fa49`: public README and staged website Homebrew installation block.
  The planned command is `brew install --cask Marios1111/tap/lidpilot`.
- Root ran the Homebrew fixtures and Pages validator/self-tests successfully;
  `scripts/verify.sh` also exited 0 with the new fixture suite.
- In a disposable localhost preview with the staged block visible, clicking
  Copy command and keyboard activation both reported success. A real paste into
  a temporary browser text field matched the exact command above. The temporary
  field was never added to the published website source.
- The normal `website/index.html` keeps the block hidden until the project tap
  and stable asset exist and the exact installation command passes. The RC4
  download and signed feed are unchanged. No further Pages publication occurred.

The owner accepted manual native cleanup before Homebrew removal or bundle
replacement. `auto_updates true` identifies Sparkle support; it does not prevent
all Homebrew upgrades. The caveat and guide require Turn Off, disable login,
Remove Helper, and Quit before a Homebrew operation replaces or removes the app.

Homebrew's native style checker subsequently ran against the generated synthetic
cask in a disposable `Casks/` directory. It found a missing trailing slash in
the homepage URL; the generator now emits `https://lidpilot.app/`. Generator
fixtures pass, and `brew style --cask` reports one file inspected, no offenses
(exit 0). This checks generated cask syntax/style, not a real release download.
The checker used temporary caches and Homebrew's development gem dependencies;
no LidPilot cask was installed or tap published.

Still required: verified stable DMG, public-byte hash comparison, tap publication,
Homebrew audit against the real cask, actual install and cleanup testing,
and reviewed activation of the website command. The short command
`brew install --cask lidpilot` requires prior tap setup or acceptance into the
official Homebrew Cask repository; neither is assumed for a fresh installation.
