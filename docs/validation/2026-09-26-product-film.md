# Product-film and website integration — September 26

Actual Remotion 4.0.529 renders: 34 seconds, 30 fps, H.264; no audio.
Landscape master: 1920×1080, 2,597,260 bytes. Vertical: 1080×1920,
2,466,848 bytes. Masters are outside Git in
`../Deliverables/LidPilot-Introduction-20260926/`.

Web encode: 1280×720, 858,504 bytes; SHA-256
`6afc627fa16573fdbdd8786d025a83a531a457915d1ff1690caee221b943e852`.
The renderer verified fast-start (`moov` before `mdat`) and a decoded 720p frame.
Lint, TypeScript and Remotion bundle checks passed. Both aspect ratios received
representative rendered-frame review before export. These are presentation
assets made from isolated native views, not physical behavior evidence.

The website uses native user-started controls, no autoplay, preload none, a
poster, English WebVTT and a timed downloadable transcript. On arrival it did
not play; an explicit native play control started playback. Computer screenshots
confirmed advancing playback and visible captions at 0:10 and 0:18, then
a stopped player at 0:34/0:34 after the film completed. The local
HTTP responses matched each committed output byte-for-byte (200). Browser
read-only video-property inspection timed out, so no programmatic duration or
track-mode assertion is claimed. Export duration is renderer metadata evidence.

Desktop and 390px responsive views were visually reviewed; a 320px DOM check
showed no horizontal overflow. Mode selection and FAQ expansion worked by
keyboard. Reduced-motion rules disable transitions and animation in source;
this is not a claim of a fresh VoiceOver or OS reduced-motion regression.
Hidden-page pause and final deployed checks remain pending.

No stable release or application-performance gate is inferred from this work.
