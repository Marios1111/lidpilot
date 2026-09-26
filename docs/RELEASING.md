# LidPilot release process

This document describes the local, staged release workflow. It does not grant
permission to publish a release. `scripts/release.sh` defaults to a dry-run
and never uploads GitHub assets, pushes Pages files, or submits notarization
unless an operator explicitly selects a stage and supplies the required
credentials.

## Inputs kept outside Git

The release operator supplies the protected signing inputs below. Placeholder
values, empty values, example domains and development identities are rejected
by preflight:

| Input | Purpose |
| --- | --- |
| `DEVELOPMENT_TEAM` | The Apple Developer Team ID used for the app and helper. |
| `LIDPILOT_DEVELOPER_IDENTITY` | Developer ID Application signing identity. |
| `LIDPILOT_NOTARY_PROFILE` | `notarytool` keychain profile. |
| `SPARKLE_TOOLS_DIR` | The reviewed Sparkle 2.10.0 `bin` directory. |
| `SPARKLE_PRIVATE_KEY_FILE` | The Ed25519 private key used only by Sparkle tooling. |
| `LIDPILOT_SPARKLE_PUBLIC_KEY` | Optional override for the public key in `Config/ReleaseDefaults.json`. |
| `LIDPILOT_GITHUB_REPOSITORY` | Optional override; defaults to `Marios1111/lidpilot`. |
| `LIDPILOT_PAGES_URL` | Optional override; defaults to the stable or RC feed for the selected channel. |
| `LIDPILOT_RELEASE_DOWNLOAD_URL` | Optional override; defaults to the immutable GitHub asset for the release label. |
| `LIDPILOT_RELEASE_CHANNEL` | Optional `stable` or `rc`; defaults to `stable`. |
| `LIDPILOT_RC_NUMBER` | Required positive integer when the release channel is `rc`. |
| `LIDPILOT_RC_TESTING_APPROVED=1` | Required explicit consent to prepare an RC for testing. |
| `LIDPILOT_HARDWARE_APPROVED=1` | Required for stable releases after the physical hardware checklist passes. |

Keep notary credentials, Developer ID certificates, Sparkle private keys and
recovery copies in protected local stores. Pull request jobs must never receive
them. `SUFeedURL` and `SUPublicEDKey` remain empty in developer builds so an
unconfigured updater can be shown as unavailable rather than pretending to be
ready. The checked-in Sparkle public key is not secret; the private key remains
outside the repository.

## Stable and release-candidate labels

Stable is the default channel. Its release label is the numeric marketing
version from `Version.xcconfig`, and its feed defaults to
`https://lidpilot.app/updates/appcast.xml`.

An RC must opt in explicitly:

```sh
LIDPILOT_RELEASE_CHANNEL=rc \
LIDPILOT_RC_NUMBER=2 \
LIDPILOT_RC_TESTING_APPROVED=1 \
./scripts/release.sh preflight
```

For marketing version `1.3.0`, this creates release label `1.3.0-rc.2`. The
app bundle keeps `CFBundleShortVersionString=1.3.0`; `CFBundleVersion` remains
the positive, strictly increasing build number from `Version.xcconfig`. The
stage directory includes both label and build, while the DMG, Sparkle archive,
notes, GitHub tag, and immutable URL use the release label. New RCs use
`https://lidpilot.app/rc/appcast.xml` and the matching
`v1.3.0-rc.2/LidPilot-1.3.0-rc.2.zip` GitHub asset path.

The existing signed RC4 feed and notes keep their original
`marios1111.github.io/lidpilot/rc/` links. The custom-domain redirect preserves
those installed clients' feed path. Do not rewrite or re-sign these historical
files as part of the domain migration. The Pages validator accepts that one
byte-pinned legacy RC4 feed explicitly; release generation only accepts the
branded feed URLs above.

An RC still requires Developer ID identity, timestamped app/helper signing,
notarization, the protected Sparkle private key, signed feed and notes, and
exact immutable URL validation. It requires `LIDPILOT_RC_TESTING_APPROVED=1`
instead of the stable hardware approval gate. Its manifest always records
`"channel": "rc"` and `"hardwareValidation": "pending"`, even if a hardware
approval variable is present. Stable manifests record hardware validation as
approved only after the stable preflight gate passes.

## Local stages

The default command is safe to run while iterating:

```sh
./scripts/release.sh
./scripts/release.sh preflight
```

The script checks the clean tree, numeric marketing version, strictly
increasing build number, release label, changelog, arm64/project settings,
release identities, updater inputs, channel-specific approval and bundle
layout before doing any signing. The archive/export stages use
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

1. Create the GitHub Release with tag `v<release-label>` and upload the final
   DMG, update archive, notes and manifest.
2. Fetch every uploaded byte back from GitHub and compare its SHA-256 with the
   local manifest. Stop on any mismatch.
3. For an RC, copy the exact signed appcast and release notes to `website/rc/`.
   Verify the appcast, archive and notes signatures against the public key,
   and compare the release assets with the manifest before committing. The
   scoped `.gitattributes` rule disables text conversion for `website/rc/*`;
   do not format, normalize, regenerate, or otherwise edit these signed bytes.
   Any byte change requires new signatures and a new manifest hash. For a
   future stable release, use the distinct `website/updates/appcast.xml` and
   `website/updates/<signed-release-notes-name>.md` paths; do not place stable
   metadata under `website/rc/`. The RC-only Pages workflow rejects a stable
   feed until a real signed stable artifact and its validation path are ready.
4. The current publisher at `.github/workflows/pages.yml` is RC-specific. To
   publish an RC, review the committed `website/` tree, open Actions, select
   the current default `dev` branch, and choose `publish-rc`; the default
   `skip` choice does not deploy. The workflow runs only for
   `workflow_dispatch`, requires that explicit choice, runs
   `scripts/validate_pages_site.rb` to check the custom domain, exact RC feed
   and immutable GitHub Release URLs, signed notes, Sparkle feed signature and
   unchanged legacy RC4 bytes, then uploads `website/` unchanged. It has no
   push, tag, release, or other automatic deployment
   trigger. GitHub Pages must be configured to use GitHub Actions as its
   publishing source. Adding the workflow and files does not dispatch it or
   publish the site. Before a stable publication, separately validate the
   stable feed and notes under `website/updates/` and update the manual
   workflow's checks to cover them.
5. Fetch the Pages files, validate signatures, URLs, build number, minimum OS
   and archive hashes, then perform the update smoke test from the last
   supported public build.

Do not use `/latest/download` as the signed archive identity, overwrite a
previously advertised asset, or publish a feed that points at bytes that have
not been fetched and checked. Keep stable and RC feeds on their configured
paths. A faulty release is recovered with a new, higher build number;
reverting only the feed cannot downgrade an installed client.

## Gates that remain independent of scripts

Passing local tests does not prove native inactivity dimming, physical
internal-panel shutdown, helper crash recovery, signed peer authentication,
notarized installation, safe helper replacement or uninstall on every supported
Mac. Those G1/G2/G3/G4/G5 gates need the documented Apple Silicon hardware,
signing and update evidence before a public release claim is made.

## Verification before the manifest

The pipeline verifies the archive, feed, and release-note signatures with the pinned Sparkle tool. It also verifies the archive with CryptoKit against the public key actually embedded in the app, preventing a mismatched signing-key release. The archive, exported app/helper team, hardened runtime, secure signing timestamps, and arm64 executables are checked before notarization/update packaging. The manifest stage repeats signature verification over the final bytes.

`scripts/verify.sh` includes a disposable Ed25519 check that rejects tampered bytes and a wrong public key. This does not replace the real signed-install/upgrade test in G5.

## Local profiling candidates

`LIDPILOT_PROFILE_BUILD=1` opts a build into `LIDPILOT_PROFILE` compilation.
It is off by default. Release tooling refuses this option for the stable channel,
uses a separate `-profile` staging directory, and records `profilingEnabled` in
its manifest. Do not publish an instrumented candidate as a normal release.
Verify that the profile subsystem is absent from normal optimized binaries and
present in both the profiling app and helper before installation.

The profiling candidate emits local unified-log events under
`com.lidpilot.profile`. It adds no root endpoint, telemetry service, or custom
privileged output path. Capture these events with macOS `log stream` (or export
with `log show`) while running the same 600-second installed CPU recorder.
Do not alter SIP to collect logs. Preserve exact commit, build, binary hashes,
start/end times, and profile-enabled status. Instrumentation overhead is included
in the candidate's CPU; a final passing gate also requires an uninstrumented
installed build using the same method.

`scripts/analyze-performance-profile.py` combines newline-delimited unified-log
JSON with `scripts/measure-performance.swift` output. It reports event counts,
calls/minute, read-path timing/child CPU, and separate app/helper/reaped-child
CPU. Sequence gaps mean event counts are incomplete. Verify capture coverage and
inspect spans crossing the measurement boundaries before interpreting results.
The analyzer's synthetic test is `python3 scripts/test-performance-profile.py`;
it does not establish an installed performance pass.
