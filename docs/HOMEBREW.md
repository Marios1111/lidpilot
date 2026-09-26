# Homebrew distribution

Homebrew is a V1 installation path for the signed, notarized Apple Silicon
release. It supports macOS 15 and later. This repository does not contain a
stable cask release yet: the current RC is not eligible, and the stable release
gates in [V1 release verification](VERIFICATION.md) must pass first. Do not
publish a cask with guessed versions, URLs, or checksums.

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

No tap or stable cask is published by this change. The planned project tap is
`Marios1111/homebrew-tap`. After it is published with the verified stable
`Casks/lidpilot.rb`, the installation command will be
`brew install --cask Marios1111/tap/lidpilot`. The generated cask is restricted to the
current `Marios1111/lidpilot` release repository.

The output file must not already exist. The generator refuses RCs, profile
builds, unapproved hardware validation, malformed release metadata, mismatched
DMG bytes, and non-versioned or non-GitHub URLs. It does not create releases,
upload assets, publish a tap, or change Gatekeeper settings. Before a cask is
published, run Homebrew's current `brew audit --cask` and `brew style` checks on
the generated file, then verify Gatekeeper accepts the exact signed and
notarized DMG on a supported Mac. Do not use `--no-quarantine` or ask users to
bypass Gatekeeper.

Sparkle is the normal in-app update owner. The cask declares `auto_updates
true`, which tells Homebrew the app can update itself. Homebrew can still
replace an installed app when its cask version is newer; `brew upgrade
--greedy-auto-updates`, `brew upgrade --greedy`, and `brew reinstall` can also
request replacement. Complete the native cleanup below before any Homebrew
operation that will replace or remove the app. A cask version update is not a
safe substitute for Sparkle's signed update flow.

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
removal, or `zap` cleanup. Those capabilities are outside this V1 distribution
addition. See the [Homebrew Cask Cookbook](https://docs.brew.sh/Cask-Cookbook)
and [Homebrew FAQ](https://docs.brew.sh/FAQ) for current cask/update behavior.
