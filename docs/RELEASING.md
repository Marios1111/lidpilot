# LidPilot release process

This document describes the local, staged release workflow. It does not grant
permission to publish a release. `scripts/release.sh` defaults to a dry-run
and never uploads GitHub assets, pushes Pages files, or submits notarization
unless an operator explicitly selects a stage and supplies the required
credentials.

## Inputs kept outside Git

The release operator supplies real values for the following inputs. Placeholder
values, empty values, example domains and development identities are rejected
by preflight:

| Input | Purpose |
| --- | --- |
| `DEVELOPMENT_TEAM` | The Apple Developer Team ID used for the app and helper. |
| `LIDPILOT_DEVELOPER_IDENTITY` | Developer ID Application signing identity. |
| `LIDPILOT_NOTARY_PROFILE` | `notarytool` keychain profile. |
| `SPARKLE_TOOLS_DIR` | The reviewed Sparkle 2.10.0 `bin` directory. |
| `SPARKLE_PRIVATE_KEY_FILE` | The Ed25519 private key used only by Sparkle tooling. |
| `LIDPILOT_SPARKLE_PUBLIC_KEY` | The matching Ed25519 public key embedded in the signed app. |
| `LIDPILOT_PAGES_URL` | The exact HTTPS appcast URL in the built app. |
| `LIDPILOT_RELEASE_DOWNLOAD_URL` | The immutable, version-specific archive URL in the appcast. |
| `LIDPILOT_GITHUB_REPOSITORY` | The intended `owner/repository` for a future GitHub Release. |
| `LIDPILOT_HARDWARE_APPROVED=1` | Maintainer record that the physical release checklist passed. |

Keep notary credentials, Developer ID certificates, Sparkle private keys and
recovery copies in protected local stores. Pull request jobs must never receive
them. `SUFeedURL` and `SUPublicEDKey` remain empty in developer builds so an
unconfigured updater can be shown as unavailable rather than pretending to be
ready.

## Local stages

The default command is safe to run while iterating:

```sh
./scripts/release.sh
./scripts/release.sh preflight
```

The script checks the clean tree, version/build monotonicity, changelog,
arm64/project settings, release identities, updater inputs, hardware gate and
bundle layout before doing any signing. The archive/export stages use
`xcodebuild` and a temporary Developer ID export options file. Notarization and
stapling use `xcrun notarytool` and `xcrun stapler`; the app is submitted as a
temporary ZIP and the original exported bundle is stapled after the ticket is
accepted. These are intentionally separate stages so an operator can inspect
each result.

Generated build products and release staging default to disposable directories
under `/private/tmp`; set `LIDPILOT_RELEASE_ROOT` or
`LIDPILOT_RELEASE_DERIVED_DATA` when a reviewed local staging location is
needed. A release stage refuses to overwrite an existing archive, export,
DMG, appcast, or update archive.

The DMG is created only from the stapled app. The final immutable Sparkle
archive is signed with the reviewed 2.10.0 `sign_update`/`generate_appcast`
tools, and the script verifies the archive, appcast and release-note signatures
with `sign_update` before writing the manifest. Feed and release-note signing
is enabled by `SURequireSignedFeed`; any change to an archive, appcast or note
requires the matching signature and a new manifest hash. The script refuses to
fabricate signatures when tools or keys are missing.

## Publication order (explicit operator action)

Publication is deliberately outside the local script. After the final
manifest has been reviewed:

1. Create the exact versioned GitHub Release and upload the final DMG, update
   archive, notes and manifest.
2. Fetch every uploaded byte back from GitHub and compare its SHA-256 with the
   local manifest. Stop on any mismatch.
3. Publish the signed appcast and signed notes to the exact GitHub Pages path.
4. Fetch the Pages files, validate signatures, URLs, build number, minimum OS
   and archive hashes, then perform the update smoke test from the last
   supported public build.

Do not use `/latest/download` as the signed archive identity, overwrite a
previously advertised asset, or publish a feed that points at bytes that have
not been fetched and checked. A faulty release is recovered with a new,
higher build number; reverting only the feed cannot downgrade an installed
client.

## Gates that remain independent of scripts

Passing local tests does not prove native inactivity dimming, physical
internal-panel shutdown, helper crash recovery, signed peer authentication,
notarized installation, safe helper replacement or uninstall on every supported
Mac. Those G1/G2/G3/G4/G5 gates need the documented Apple Silicon hardware,
signing and update evidence before a public release claim is made.

## Verification before the manifest

The pipeline verifies the archive, feed, and release-note signatures with the pinned Sparkle tool. It also verifies the archive with CryptoKit against the public key actually embedded in the app, preventing a mismatched signing-key release. The archive, exported app/helper team, hardened runtime, secure signing timestamps, and arm64 executables are checked before notarization/update packaging. The manifest stage repeats signature verification over the final bytes.

`scripts/verify.sh` includes a disposable Ed25519 check that rejects tampered bytes and a wrong public key. This does not replace the real signed-install/upgrade test in G5.
