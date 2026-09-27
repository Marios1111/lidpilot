# LidPilot launch candidate

Status: **staged, unpublished**. This 45-second edit is separate from the existing 42-second film. Do not replace public media until the project Homebrew tap and stable cask have been published and verified, and the owner has checked the narration by ear.

The install card shows the launch-staged command:

```sh
brew install --cask Marios1111/tap/lidpilot
```

## Creative direction

The opening shows two concrete benefits: keeping a lecture visible and letting a build finish with the lid closed. The menu-bar product reveal then leads through the two modes, one deliberate Follow Lid opening, and a clean change from an active session to Off. The final card presents native macOS support, free and open-source availability, installation, and the closing line in that order.

The approved rigid laptop illustration and actual V1 panel captures are reused. The work progress graphic is illustrative; it does not suggest app detection or automatic task monitoring. The three mode names and manual session controls remain the product story. There are no competitor comparisons or AI-agent detection claims.

The legacy compositions retain their timing, original narration, and default component behavior. The optional `presentation="launch"` on `ProductScene` gives the candidate shorter entrances and keeps the running laptop closed after the hook has already demonstrated closure.

## Narration

Selected asset: `public/narration-launch-candidate-take-1.mp3`, copied from the owner-approved ElevenLabs take 1. The production owner reported the approved voice as **Will Relaxed Optimist**, ID `bIHbv24MWmeRgasZH58o`. No additional paid generation was performed for this edit.

SHA-256: `15ae416591ea7394312d595812ab73491c0c0b827f8219f2db3867bfe4d18aec`

Decoded source duration: **40.124082 seconds**. Placement: frame 33, or **1.100 seconds**. The audio plays at its original speed, with no speech time-stretch. The low-resolution encoded preview adds approximately 68 ms of codec delay to the measured source landmarks.

Approved script:

> Keep the lecture in view.
> Let the build finish, even when you close the lid.
> LidPilot puts those choices right in your Mac’s menu bar.
> Keep Screen On for lectures, reading, and focused work.
> Keep Mac Running for builds, downloads, or a local AI task.
> Or let Follow Lid connect the two.
> Choose how long you need it. Stop whenever you want.
> Native to macOS. Free and open source.
> Install with Homebrew, or download it from lidpilot.app.
> LidPilot. Your Mac, on your time.

## Timing

The timeline is defined in `story-launch-candidate.json`: 1,350 frames at 30 fps. The scene changes sit inside pauses measured in the actual encoded preview using silence detection at −35 dB with a 220 ms minimum. Caption timing follows these sentence boundaries; it is not a word-level forced alignment.

| Scene | Visual interval | Measured pause containing its opening cut |
| --- | --- | --- |
| Lecture hook | 0.000–3.000 s | Opening |
| Closed-lid work hook | 3.000–6.767 s | 2.605–3.436 s |
| Product reveal | 6.767–10.900 s | 6.269–7.357 s |
| Keep Screen On | 10.900–15.433 s | 10.555–11.388 s |
| Keep Mac Running | 15.433–20.700 s | 14.980–16.040 s |
| Follow Lid | 20.700–23.900 s | 20.384–21.198 s |
| Session control | 23.900–28.400 s | 23.529–24.517 s |
| Native / free / installation | 28.400–45.000 s | 28.124–28.762 s |

The Homebrew card begins its 600 ms entrance at 32.500 s and remains fully visible from 33.100 s until the end. The final detectable speech ends around 40.971 s in the preview. The last caption ends at 41.267 s, leaving 3.733 seconds of a clear final card. The MP4 has exactly 45 seconds of video; AAC packet padding gives the preview a 45.056-second container duration.

## Preview and render

Use Node 24 and the already pinned Remotion 4.0.529 dependencies. The new compositions appear in the **Launch-candidate** folder:

- `LidPilotLaunchLandscape`: 1920 × 1080, external captions.
- `LidPilotLaunchLandscapeSocial`: 1920 × 1080, burned captions.
- `LidPilotLaunchVertical`: 1080 × 1920, external captions.
- `LidPilotLaunchVerticalSocial`: 1080 × 1920, burned captions.

Run from `media/film`. These commands write only to ignored candidate output:

```sh
npm run lint
node scripts/export-launch-captions.mjs
npx remotion render src/index.ts LidPilotLaunchLandscapeSocial out/launch-candidate/landscape.mp4 --codec=h264 --crf=16 --concurrency=2
npx remotion render src/index.ts LidPilotLaunchVerticalSocial out/launch-candidate/vertical.mp4 --codec=h264 --crf=16 --concurrency=2
npx remotion render src/index.ts LidPilotLaunchLandscape out/launch-candidate/web.mp4 --scale=0.6666666667 --codec=h264 --crf=24 --audio-bitrate=160k --concurrency=2
npx remotion still src/index.ts LidPilotLaunchLandscape out/launch-candidate/poster.jpg --frame=1338 --scale=0.6666666667 --image-format=jpeg
```

The launch caption exporter validates scene continuity, total length, narration bounds, caption bounds, and non-overlapping cues. An optional first argument chooses another candidate output directory. It does not write the public film sidecars.

## Review evidence and limitations

- The reviewed published input was `website/assets/lidpilot-intro-web.mp4`, SHA-256 `ca398bd0a60de84b28f66ff16e6737ba11e729fa0f09a17c5604353cc12d1fa9`. The older `media/film/web` movie was not used as the current reference.
- 24 candidate stills were rendered across landscape and portrait. Visual inspection covered the hooks, product reveal, both individual modes, Follow Lid, session stop, native/free messages, install card, and final hold. The full command fits in portrait with clear caption separation.
- The 960 × 540 preview contains 1,350 H.264 video frames. Its audio was decoded for pause measurements. An encoded install-card frame was also inspected.
- The environment could not provide audio perception. **Naturalness, pronunciation, and the final audible mix still need an owner ear-check.** This review does not claim to have listened to the narration.
- Browser/native playback was unavailable while the Mac was locked; rendered frames provide the visual evidence. No hardware behavior was tested through this creative work.
- No public movie, original narration, website asset, app behavior, or laptop geometry was changed by this candidate edit.

Final candidate exports, hashes, and the source fingerprint are recorded in the dated candidate deliverables README. They remain launch-staged until the publishing prerequisites above are met.
