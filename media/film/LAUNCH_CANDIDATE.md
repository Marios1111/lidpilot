# LidPilot launch candidate — take 2

Status: **staged, unpublished**. This 41-second edit uses the owner's preferred narration take 2. It is separate from the existing 42-second public film and the preserved 45-second take 1 delivery. Do not replace public media until the project Homebrew tap and stable cask have been published and verified.

The install card retains the fully qualified launch-staged command:

```sh
brew install --cask Marios1111/tap/lidpilot
```

The short command `brew install --cask lidpilot` is not currently a standalone install path.

## Creative direction

The opening shows two concrete benefits: keeping a lecture visible and letting a build finish with the lid closed. The menu-bar product reveal leads through the two modes, one deliberate Follow Lid opening, and a clean change from an active session to Off. The final card presents native macOS support, free and open-source availability, installation, and the closing line in that order.

The approved rigid laptop illustration and actual V1 panel captures are retained. The work progress graphic is illustrative; it does not suggest app detection or automatic task monitoring. There are no competitor comparisons or AI-agent detection claims.

Take 2 has a shorter conversational delivery. Scene cuts, captions, the first lid closure, the stop action, and the final-card entrances were retimed to its natural sentence pauses. The work-mode caption now stays together for the whole sentence. The original narration assets, public compositions, and previous deliverables remain unchanged.

## Narration

Selected asset: `public/narration-launch-candidate-take-2.mp3`, copied from the already generated `/private/tmp/lidpilot-launch-narration-take-2.mp3`. The owner selected this take by ear. The production owner reported the approved voice as **Will Relaxed Optimist**, ID `bIHbv24MWmeRgasZH58o`. No additional paid generation was performed.

SHA-256: `c31be839d6d9a9b91ddd501f6dd780f0e736150ba3787ba7012c01a35bd2a1bf`

Decoded source duration: **35.480091 seconds**; MP3 container duration: **35.526531 seconds**. Placement: frame 33, or **1.100 seconds**. The audio plays at its original speed, with no speech time-stretch. The encoded preview adds approximately 68 ms of codec delay to the source landmarks.

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

The timeline in `story-launch-candidate.json` contains **1,230 frames at 30 fps** and **13 caption cues**. Every scene change falls inside an actual encoded-preview pause measured at −35 dB with a 220 ms minimum. All 13 captions cover the corresponding sentence speech intervals. This is sentence-level timing against the known script, not word-level forced alignment.

| Scene | Visual interval | Encoded pause containing its opening cut |
| --- | --- | --- |
| Lecture hook | 0.000–2.833 s | Opening |
| Closed-lid work hook | 2.833–6.267 s | 2.511–3.270 s |
| Product reveal | 6.267–9.900 s | 5.896–6.739 s |
| Keep Screen On | 9.900–13.533 s | 9.608–10.284 s |
| Keep Mac Running | 13.533–17.800 s | 13.202–14.006 s |
| Follow Lid | 17.800–20.667 s | 17.486–18.220 s |
| Session control | 20.667–24.800 s | 20.210–21.207 s |
| Native / free / installation | 24.800–41.000 s | 24.463–25.250 s |

The Homebrew card begins its 600 ms entrance at **28.300 s** and remains fully visible from **28.900 s** until the end. Final detectable speech ends at **36.351 s** in the preview; the last caption ends at **36.600 s**, leaving **4.400 seconds** of a clear final card. The MP4 contains exactly **41.000 seconds** of video; AAC packet padding gives the preview a **41.045333-second** container duration.

## Preview and render

Source revision: `bfbec56` (the source fingerprint in the delivery folder records the full revision and exact file hashes). Use Node 24 and the pinned Remotion 4.0.529 dependencies. The candidate compositions remain in the **Launch-candidate** folder:

- `LidPilotLaunchLandscape`: 1920 × 1080, external captions.
- `LidPilotLaunchLandscapeSocial`: 1920 × 1080, burned captions.
- `LidPilotLaunchVertical`: 1080 × 1920, external captions.
- `LidPilotLaunchVerticalSocial`: 1080 × 1920, burned captions.

Run from `media/film`. These commands write to ignored candidate output:

```sh
npm run lint
node scripts/export-launch-captions.mjs out/launch-candidate-take2
npx remotion render src/index.ts LidPilotLaunchLandscapeSocial out/launch-candidate-take2/landscape.mp4 --codec=h264 --crf=16 --concurrency=2
npx remotion render src/index.ts LidPilotLaunchVerticalSocial out/launch-candidate-take2/vertical.mp4 --codec=h264 --crf=16 --concurrency=2
npx remotion render src/index.ts LidPilotLaunchLandscape out/launch-candidate-take2/web.mp4 --scale=0.6666666667 --codec=h264 --crf=24 --audio-bitrate=160k --concurrency=2
npx remotion still src/index.ts LidPilotLaunchLandscape out/launch-candidate-take2/poster.jpg --frame=1218 --scale=0.6666666667 --image-format=jpeg
```

The launch caption exporter validates scene continuity, total length, narration bounds, caption bounds, and non-overlapping cues. An optional first argument selects another candidate output directory. It does not write public sidecars.

## Review evidence and limitations

- Thirty take 2 stills were rendered across landscape and portrait. Visual inspection covered the retimed work-mode caption, Follow Lid, session stop, installation, closed-lid hold, and closing line. The full command fits portrait and remains separate from captions.
- The 960 × 540 preview contains 1,230 H.264 frames. Audio decoding verified the pauses and caption intervals. The dated delivery folder includes full-resolution exports, encoded-frame samples, stream metadata, timing measurements, and hashes.
- The owner accepted take 2 by ear. This execution environment could not provide audio perception, so the agent's review establishes measured synchronization and rendered layout; it does not claim an independent listening review of the final encoded mix.
- No app behavior or physical hardware was tested through this creative work. Laptop geometry, the public movie, the original narration, and the first candidate delivery were preserved.
- The published input remains `website/assets/lidpilot-intro-web.mp4`, SHA-256 `ca398bd0a60de84b28f66ff16e6737ba11e729fa0f09a17c5604353cc12d1fa9`.

Delivery folder: `/Users/marios/Documents/👨🏼‍💻/coding mac/LidPilot/Deliverables/LidPilot-Launch-Candidate-Take2-20260927/`. Its README records exact hashes, source provenance, verification results, and publication status. No publication is performed by the film workflow.
