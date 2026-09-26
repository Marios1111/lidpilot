# XPC callback executor correction — September 27, 2026

The installed RC9 no-update cycle reproduced the failure recorded in
[RC9 validation](2026-09-27-rc9-validation.md). Exact exported binary/dSYM
UUID `0C080066-2DBB-350F-8FB5-2E82BF669166` matched the crash report.
Symbolication maps the fault to the error-handler closure in
`XPCTransport.send` (`Runtime/HelperTransport.swift`, previously line 197),
called on the NSXPC connection queue. Swift's executor check asserted before
the handler could finish its continuation.

The error, reply and timeout closures are now constructed by top-level callback
factories outside the MainActor transport method. The project uses Swift 6.0
strict concurrency and no default MainActor isolation setting. The existing
lock-protected `ReplyOnce` still admits exactly one completion. The 30-second
timeout, reply decoding/validation, identity requirements, stale-state fencing,
helper watchdog, leases and power read-back remain unchanged. No unchecked
sendability was added; the existing locked holder is internal for the regression.

`remoteObjectErrorCallbackResumesFromDetachedExecutor` constructs the actual
error handler from a MainActor test and invokes it from a detached executor.
The continuation returns the expected error. This is a deterministic callback
regression, not an installed XPC or hardware test.

- Focused HelperTransportTests: 6 tests, exit 0.
- Full Core/Runtime: 21 + 69 = **90 tests**, zero failures, exit 0.
- Test scratch: `/private/tmp/lidpilot-rc9-xpc-callback/full`.
- Debug: exit 0, `/private/tmp/lidpilot-rc9-callback-debug.log`.
- Release: exit 0, `/private/tmp/lidpilot-rc9-callback-release.log`.
- Installed signed no-update/error/recovery regression remains pending a freshly
  built candidate. RC9 itself is not retroactively marked fixed.
