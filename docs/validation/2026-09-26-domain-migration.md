# Permanent domain migration — September 26, 2026

## Observed deployment before source changes

The reported GitHub Pages 404 did not reproduce during this continuation.
`https://lidpilot.app/` returned HTTP 200. Its public HTML matched the existing
repository page byte for byte (SHA-256
`60254d41450651ae123edc60c30f5d22fb877d6ffad0c6131942610868613f77`).
This establishes the previously deployed page, not deployment of the redesign.
No cause for the earlier transient 404 is claimed.

GitHub reported workflow-based Pages publishing, custom domain `lidpilot.app`,
verified ownership and an approved HTTPS certificate covering both the apex and
`www.lidpilot.app` (expiry December 24, 2026). The last successful Pages workflow
was run `35920856009`, source `4f1fe2f6650a8626f5b0cbe9e69ca924be21d0a8`.
Its Actions artifact was no longer listed by the artifacts API; the publicly
served HTML was compared instead.

Cloudflare's existing apex and `www` CNAMEs both pointed to
`marios1111.github.io`, with proxying disabled. They were left unchanged.
The existing GitHub Pages architecture did not require a DNS repair.

## HTTPS and redirects

GitHub initially reported `https_enforced: false`. Under the explicit domain
integration request it was enabled. After the cached HTTP response expired,
read-only requests at approximately 17:48 UTC confirmed:

| URL | Observed result |
| --- | --- |
| `http://lidpilot.app/` | 301 to `https://lidpilot.app/` |
| `https://www.lidpilot.app/` | 301 to `https://lidpilot.app/` |
| `http://www.lidpilot.app/` | 301 to `https://lidpilot.app/` |
| `https://lidpilot.app/` | 200, existing published page |
| `https://marios1111.github.io/lidpilot/rc/appcast.xml` | Redirect to branded `/rc/appcast.xml`, then 200 |

These requests were made from the local validation host against the public
service. Independent remote-run URL checks and the redesigned site deployment
remain pending; they must not be inferred from local curl or source changes.

## Feed contract

The intended stable endpoint is `https://lidpilot.app/updates/appcast.xml`.
New release candidates use `https://lidpilot.app/rc/appcast.xml`. Binaries remain
at immutable version-specific GitHub Release URLs. Existing RC4 signed feed and
release-note bytes must remain unchanged during migration; redirecting their
old URL is not permission to rewrite their signed contents.

The stable endpoint is not yet a published stable feed. Domain availability
neither closes the engineering gates nor authorizes a stable-release claim.
