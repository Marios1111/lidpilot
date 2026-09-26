# Independent performance review and bounded follow-up

The owner supplied an independent Astra Pro review on September 26. It is
read-only source/accounting analysis, not a new Mac measurement, build or
hardware result. The source package SHA-256 was
`b7cea93dd5cd18555d3e1a86926b96b339aacc519cfcd14cdc611c9b444aa483`;
all 83 manifest entries matched. Installed RC6 source was `5a44e31`;
current development source and later UI/identity changes were treated separately.

Retained review: [source evidence](evidence/pro-source-review-20260926.md) and
[recomputed accounting](evidence/pro-accounting-audit-20260926.json).

## Accepted findings

The independent arithmetic reproduces 0.830469760% inclusive CPU in
600.000991 seconds: 2.135622 app CPU seconds, 0.324441 helper seconds, and
2.522764 reaped-child seconds. The budget is about 1.2 CPU seconds. No accounting
error reverses FAIL; no documented cheaper equivalent reader was identified.
Command-boundary accounting remains a limitation of the uninstrumented record.

Apple's published CLI/IOKit source reads the reported `SleepDisabled` value from
system-power preferences. Independent reads establish fresh CLI-reported
configuration, not a documented synchronous kernel acknowledgment. This does
not remove any read, assertion, fence, lease or recovery safeguard. Physical
workload continuity and panel darkness remain separate hardware evidence.

Three opportunities were identified: hidden presentation isolation; avoiding
polling a closed output pipe before child exit; and canceling completed XPC
request timeout work. The latter two are source-derived cleanup opportunities,
not measured explanations of child CPU and not part of the experiment below.

The analyzer also incorrectly marked a boundary-crossing command trace as
complete. A focused regression reproduced that defect, then the completeness
condition was corrected. Existing retained instrumented records had no boundary
spans, so their published totals are unchanged.

## One isolated experiment

Use a managed checkout based on measured `5a44e31`. Candidate B changes only
AppKit-driven mounting of closed MenuBarExtra/Settings content. Keep the model,
status item, observers, renewals, assertions, XPC and helper implementation alive
and unchanged. Reopening must show current state; Stop, expiry, and accessibility
must still work. Occlusion alone is not treated as window closure.

Build uninstrumented A and B with the same toolchain and helper. Verify a short
native lifecycle diagnostic separately, then run A1 → B → A2, 600 seconds each,
on the accepted current Mac with unchanged OS, power, lid, mode, warm-up and
window-interaction history. Record artifact identities, app/helper/children,
memory and wakeups; no heavy tracing or rendering during captures. Verify
ownership before and cleanup afterward. Do not invent uninstrumented read counts.

Predeclared diagnostic retention rule: B app CPU must be at least 0.05 percentage
points below both A values and the reduction must exceed A1/A2 drift. This is an
experiment screening rule, not a statistical confidence interval or a release
threshold. An inconclusive/absent effect closes the hypothesis. No speculative
public RC is needed. Full inclusive CPU still must actually meet ≤0.2%.

At unchanged measured helper/child costs, eliminating all app CPU leaves
0.474533%. Presentation work is therefore not promised to solve the full gate.
If the bounded investigation still fails, retain FAIL and seek an explicit
contract/budget decision; do not reduce safety or relabel the measurement.
