# Runtime icon memory attribution — September 26

RC7's controlled installed capture passed inclusive CPU at 0.903801%, but
memory failed at 75.648805 MiB mean / 76.032715 MiB sampled maximum. It was
returned to verified Off before this investigation. App footprint stayed nearly
flat during the capture; no runaway growth was observed.

The Off-state public `vmmap -summary` reported CG Image regions of 16.2 MiB
virtual, 11.5 MiB dirty. Source allocated a 512-point resolved app-icon bitmap
from the 1024-pixel appearance-aware artwork at launch/appearance change.

A disposable no-window AppKit harness loads the installed bundle's same asset
and compares only the icon assignment path. It does not connect to the helper,
write power state, change system appearance, or measure installed acceptance.
[Harness source](2026-09-26-icon-memory-harness.swift) is retained for reproduction.

| Process case | Baseline footprint | Final footprint |
| --- | --- | --- |
| Existing 512-point resolved raster | 5.672493 MiB | 30.547653 MiB |
| 256-point resolved raster | 5.813141 MiB | 18.610130 MiB |
| Direct catalog image (earlier attempt) | 5.609993 MiB | 46.375755 MiB |

Direct image reuse increased the harness footprint; that source attempt was
reverted and was never committed or installed. The smaller resolved raster
reduces final harness footprint by about 11.94 MiB. This is attribution evidence,
not a guaranteed installed reduction. A new controlled installed capture is
required; no acceptance pass is claimed from this comparison.

The fix keeps the public AppKit appearance observation and resolved drawing path,
with a 256-point runtime image. Public CGImage inspection confirms a
512×512-pixel resolved image on this Retina host. Full-resolution AppIcon assets, named artwork,
masters, and native in-app marks remain unchanged. No state observation, command,
watchdog, lease, fencing, conflict or recovery behavior changes.

Checks: Debug and Release builds pass, exit 0. The actual isolated Debug mock app
passes activation, cleanup, rendered light/dark fixtures and normal exit, exit 0.
These fixtures are not final installed accessibility or panel hardware evidence.
The full automated suite passes 68 Runtime + 21 Core tests (89), exit 0, including
three new native journal rejection cases. Installed memory acceptance is pending.
