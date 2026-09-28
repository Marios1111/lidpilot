# Homebrew distribution

Homebrew is an installation path for the signed, notarized Apple Silicon
release. It supports macOS 15 and later. The verified stable cask is published in
[Marios1111/homebrew-tap](https://github.com/Marios1111/homebrew-tap). Its checksum
matches the immutable signed/notarized stable DMG. See
[Release verification](VERIFICATION.md) for evidence and boundaries.

The cask is generated from the final release manifest and the exact local DMG
whose SHA-256 is recorded there. The generator accepts only a non-profiled
stable release with approved hardware validation, validates the versioned
GitHub Release asset URL, and hashes the DMG again before rendering the cask.
This is consistency checking, not provenance verification: it does not
authenticate the manifest or independently verify Developer ID signing,
notarization, or Gatekeeper acceptance. Those remain release-pipeline and
supported-Mac checks. After publishing a release, fetch the GitHub DMG back and
compare its SHA-256 to the manifest before publishing or announcing the cask.

```sh
# Replace these placeholders with the exact final stable stage, published asset URL,
# and a new path in the intended tap checkout before running the generator.
MANIFEST_PATH="<final-stable-stage>/manifest.json"
DMG_PATH="<final-stable-stage>/LidPilot-<version>.dmg"
GITHUB_DMG_URL="<versioned-GitHub-Release-DMG-URL>"
CASK_PATH="<tap-checkout>/Casks/lidpilot.rb"

ruby scripts/generate_homebrew_cask.rb \
  --manifest "$MANIFEST_PATH" \
  --dmg "$DMG_PATH" \
  --download-url "$GITHUB_DMG_URL" \
  --output "$CASK_PATH"
```

## Install

```sh
brew install --cask Marios1111/tap/lidpilot
```

Or add the tap once and use the short command:

```sh
brew tap Marios1111/tap
brew install --cask lidpilot
```

This is the project tap, not a claim of inclusion in Homebrew’s official Cask repository.

The output file must not already exist. The generator refuses RCs, profile
builds, unapproved hardware validation, malformed release metadata, mismatched
DMG bytes, and non-versioned or non-GitHub URLs. It does not create releases,
upload assets, publish a tap, or change Gatekeeper settings. Before a cask is
published, run Homebrew's current `brew audit --cask` and `brew style` checks on
the generated file, then verify Gatekeeper accepts the exact signed and
notarized DMG on a supported Mac. Do not use `--no-quarantine` or ask users to
bypass Gatekeeper.

V2 detects a Homebrew receipt/path and defaults to **Homebrew** update ownership.
Settings → Updates allows an explicit choice of Homebrew, Sparkle, or Manual.
Homebrew/manual ownership disables Sparkle checks and installation. The cask
retains `auto_updates true` because the app supports optional in-app updates;
use `--greedy` when upgrading it through Homebrew.

After the native cleanup below, update an existing installation with:

```sh
brew update
brew upgrade --cask --greedy Marios1111/tap/lidpilot
```

Open LidPilot after replacement. It starts Off; enable its helper again for
closed-lid modes and restore Launch at login if desired.

## Required cleanup before Homebrew removal or replacement

Homebrew's supported cask uninstall hooks cannot enforce LidPilot's app-owned
cleanup. The available official `uninstall_preflight_steps` are declarative
file operations, while the legacy Ruby preflight hook is private API and is
rejected for official casks. The cask therefore has no automatic guard.
Directly running `brew uninstall --cask lidpilot` without this preparation is
unsupported and unsafe: removing the app bundle first can leave helper
registration or sleep-control state unresolved.

With the lid open, use the normal app UI and complete the same sequence as
[Uninstalling LidPilot](UNINSTALL.md):

1. Choose **Turn Off** and wait until LidPilot confirms cleanup.
2. In **Settings → General**, disable **Launch at login**.
3. In **Settings → Helper & Recovery**, choose **Remove Helper…** and confirm.
4. Wait for LidPilot to report the helper removed, then quit the app normally.
5. Only then run `brew uninstall --cask lidpilot`, or run the Homebrew upgrade
   or reinstall that will replace the bundle.

If LidPilot cannot launch or reports **Recovery required**, do not remove or
replace the app bundle. Follow [Recovery](RECOVERY.md) or ask a maintainer to
review the observed state. Homebrew does not remove helper registrations,
change `pmset`, or repair LidPilot's recovery journal.

The cask intentionally adds no CLI, global shortcut, `sudo` command, launchd
removal, or `zap` cleanup. The app provides opt-in CLI installation and global
shortcuts separately; the cask does not change shell configuration or system
permissions. See the [Homebrew Cask Cookbook](https://docs.brew.sh/Cask-Cookbook)
and [Homebrew FAQ](https://docs.brew.sh/FAQ) for current cask/update behavior.
