# LidPilot website

Static GitHub Pages content for **https://lidpilot.app/**. HTML, CSS and a small
first-party script provide responsive layout, native mode previews and video
controls. There are no third-party fonts, analytics, cookies, WebGL or frontend
runtime dependencies. GitHub links remain authoritative for source, issues and
immutable release artifacts.

The public presentation is evergreen product copy. The download identifies the
actual available release; change it to stable only when that artifact exists.
Engineering gate status belongs in `docs/VERIFICATION.md`, not the landing-page
hero or promotional film.

Native product images are exported from the actual SwiftUI/AppKit views through
the Debug-only isolated capture harness. Supported session states are staged
with simulated power controls; these screenshots are not hardware-test proof.
Product captures omit the QA banner; interactive QA previews retain it.

The 34-second Remotion film is silent and user-started, with a poster, English
WebVTT captions and a transcript. `preload="none"` avoids blocking the initial
page with video bytes. Reduced Motion receives a still poster until explicit
Play; hidden-page playback is paused. Full social masters stay outside Git.
See `media/film/README.md` for reproducible source and renders.

`CNAME` declares `lidpilot.app`. New stable metadata uses
`https://lidpilot.app/updates/appcast.xml`; the retained signed RC feed remains
at `/rc/appcast.xml` and its signed bytes must not be edited during migration.
Validate with `ruby scripts/validate_pages_site.rb --self-test` before the manual
Pages workflow. That workflow publishes `website/` unchanged and does not create
a stable app release.

Local preview: `python3 -m http.server 8766 --directory website`.
