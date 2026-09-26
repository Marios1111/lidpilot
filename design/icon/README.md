# LidPilot LP icon

Light and dark master artwork follows the owner's September 25 LP concept:
charcoal/white rounded L, slate-blue open P bowl, and a quiet rounded tile.
The masters were recreated from the supplied board with image generation;
no board text or unrelated mockup assets are included.

Run `swift design/render-icon.swift` from the repository root to compile
all ten macOS app-icon sizes and the adaptive `PilotIcon` image asset.
The masters are retained for reproducible resizing. No runtime image generation
or image dependency is used.

The default Finder/bundle icon is light. Native in-app artwork and the running
application icon follow Light/Dark appearance through public SwiftUI/AppKit APIs.
This does not claim a macOS 15 Finder dark-icon capability. The menu-bar status
symbol remains a native template symbol so status and contrast stay legible.
