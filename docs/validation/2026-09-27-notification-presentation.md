# Notification presentation correction — September 27, 2026

The installed RC8 foreground one-minute session ended Off and cleaned up its
assertions, but the owner observed no notification banner or sound. Both OS and
app notification settings were restored to their original Off values. The
[installed record](2026-09-26-rc8-acceptance.md) distinguishes this negative
observation from an untested background-delivery failure.

Source inspection found no foreground delegate and no content sound. The
correction uses Apple's public [notification delegate](https://developer.apple.com/documentation/usernotifications/unusernotificationcenterdelegate)
API to request banner/list/sound presentation only while the live app remains
opted in and is not a preview. The framework callback is nonisolated and hops
to the main actor to read preferences; its Sendable completion is called once.
SwiftUI retains the application delegate. Preview launches do not assign the
real notification-center delegate. Event content has the default sound; OS
notification/Focus preferences still control delivery. Enqueue errors are
recorded locally rather than silently discarded. No helper, lease, power,
update or permission policy was changed.

Checked working tree: `942dd03349529a33d505baf2e38f8658d53adbb3` plus the two
App changes included with this record. Implementation: Luna Max; integration
and diff review: Astra lead.

- `scripts/test.sh`: exit 0, 68 Runtime + 21 Core tests (89 total).
- Debug: exit 0; `/private/tmp/lidpilot-notification-closeout/debug-build.log`.
- Release: exit 0; `/private/tmp/lidpilot-notification-closeout/release-build.log`.
- Initial sandboxed preview launch aborted inside AppKit application registration
  before application callbacks. A bounded execution of the existing isolated
  mock smoke outside the sandbox then passed, exit 0: actual Debug app activation,
  cleanup, rendering and normal exit. This is not hardware or notification proof.
- No app-level notification unit-test target exists. No installed delivery PASS
  is claimed. Repeat authorized foreground/background delivery on the fresh
  signed candidate, retaining OS permission and Focus context.

The pre-existing updater KVO actor-isolation warning is separate from this fix.
The installed RC8 remains unchanged and Off; its controlled AC acceptance capture
still awaits charger availability.
