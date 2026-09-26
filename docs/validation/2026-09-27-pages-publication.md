# Authorized polished-site Pages publication — September 27, 2026

The owner explicitly authorized a one-time exception to the production-write
restriction for this RC website publication only. No stable app/release/feed
was published.

Committed source: `13342a8c418afee823dcd089e77a0bc2718c977d`.
GitHub Pages workflow: `36279153700`, conclusion success.
https://github.com/Marios1111/lidpilot/actions/runs/36279153700

The existing manual `pages.yml` workflow was dispatched on dev with
`publication=publish-rc`; its metadata validator passed without rewriting RC4.
Public byte inspection matched the committed website files:

| File | Bytes | SHA-256 |
| --- | --- | --- |
| index.html | 10545 | bdbd25b93800af14e0ff4a2f6908c860d346ac80eb2ff8134ff9f8516f6c5cb1 |
| assets/lidpilot-intro-web.mp4 | 3706810 | ca398bd0a60de84b28f66ff16e6737ba11e729fa0f09a17c5604353cc12d1fa9 |
| assets/film-poster.jpg | 23000 | d1715a3d76c7847c609297b5ffb94119c39d8702b6d282e94b8999a00350a9dc |
| assets/lidpilot-intro.vtt | 738 | 9fc5f5cd1a0a22a047f26a2472199e245d9bd6c9f1ce61063e4af3320d381acb |
| rc/appcast.xml | 1616 | 6722017a74a3aaae46d7ab4452cc4bce98deefbcef54d2084057b37ae464423e |

`http://lidpilot.app/` returns 301 to HTTPS apex.
`https://www.lidpilot.app/` returns 301 to HTTPS apex.
HTTPS apex returns 200 with a normally validated certificate. Native in-app
browser opened the actual public page and showed the new hero, real mode
image, introduction video controls, captions/transcript, accessible navigation
and explicit RC4 prerelease download wording. Rendered narrow viewport showed
no overlapping hero controls. Full final performance/accessibility QA remains
separate; no Lighthouse score is invented.

Stable `https://lidpilot.app/updates/appcast.xml` remains unpublished (404).
Domain/DNS architecture was preserved; no Cloudflare setting was modified.
