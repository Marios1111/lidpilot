# LidPilot film source

The revised **45-second Homebrew launch edit** is staged separately. See
[LAUNCH_CANDIDATE.md](LAUNCH_CANDIDATE.md) for its compositions, narration,
timing review, export commands and publication prerequisites. The current
public website still uses the 42-second film described below.

This project builds four 42-second, 30 fps compositions from the shared
storyboard: `LidPilotLandscape` and `LidPilotVertical` keep narration captions
as a sidecar for web playback; `LidPilotLandscapeSocial` (1920×1080) and
`LidPilotVerticalSocial` (1080×1920) burn those same timed captions into the
social masters. Native screenshots are stored as source inputs under
`public/native/` without recoloring or simulated interaction. The current views
were staged in isolated Debug controls; the staging provenance is recorded in
`media/README.md`, not added to the product film. Original vector laptop scenes
carry the story; the native captures remain the only product UI evidence.

`public/narration-take-1.mp3` is the owner's approved ElevenLabs take. The
composition places it after a 3-second visual lead-in, leaving a short
end-card hold in the 42-second film. Final playback review remains pending.

## Prepare and validate

Use Node 24 from the repository's `.nvmrc`:

```sh
source ~/.nvm/nvm.sh
nvm use 24
cd media/film
npm ci
npm run sync:assets
npm run captions
npm run lint
npm run build
```

The storyboard in `story.json` is the source for the scene schedule, both
caption treatments, the timed WebVTT sidecar, and transcript. `npm run
sync:assets` copies the current five native inputs from `website/assets/` into
this project; review the resulting diff when those source captures change.

## Preview and render

Open the compositions in Remotion Studio with `npm run dev`. Review representative
frames from both aspect ratios, including the burned-in caption safe areas,
before rendering any complete export. After that review, render as needed:

```sh
npm run render:landscape-master
npm run render:vertical-master
npm run render:web
npm run render:poster
```

The 1280×720 H.264 web encode, JPEG poster, captions, and transcript go in
`web/`; the web composition has no burned-in captions, so an embedded VTT track
can be enabled without duplication. Full-resolution social masters and
Remotion caches go in ignored `out/` and `build/` directories. The web encode
and poster should be committed only after visual review. The vector task line is illustrative. The source makes no claim of
immediate electrical panel shutdown, universal external-display support,
idle-dimming independence, task detection, or agent-completion automation.
