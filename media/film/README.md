# LidPilot film source

This project builds two 34-second, 30 fps compositions from the shared
storyboard: `LidPilotLandscape` (1920×1080) and `LidPilotVertical` (1080×1920).
Native screenshots are stored as source inputs under `public/native/` without
recoloring or simulated interaction. The current views were staged in isolated
Debug controls; the staging provenance is recorded in `media/README.md`, not
added to the product film.

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

The storyboard in `story.json` is the source for the scene schedule, WebVTT
sidecar, and transcript. `npm run sync:assets` copies the current five native
inputs from `website/assets/` into this project; review the resulting diff when
those source captures change.

## Preview and render

Open the compositions in Remotion Studio with `npm run dev`. Review representative
frames from both aspect ratios before rendering any complete export. After that
review, render as needed:

```sh
npm run render:landscape-master
npm run render:vertical-master
npm run render:web
npm run render:poster
```

The 1280×720 H.264 encode, JPEG poster, captions, and transcript go in `web/`.
Full-resolution masters and Remotion caches go in ignored `out/` and `build/`
directories. The web encode and poster should be committed only after visual
review. The source contains no audio and makes no claim of immediate electrical
panel shutdown, universal external-display support, idle-dimming independence,
workload detection, or agent-completion automation.
