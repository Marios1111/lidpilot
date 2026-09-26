# Bounded EOF runner investigation — September 26

Inspected base: `353819a` on dev. A harmless fixture closes stdout/stderr,
then sleeps for 300 ms. No privileged operation or power write is performed.
Before the fix the isolated run used 0.308079 seconds of process CPU in
0.313 seconds elapsed. The new regression failed as expected.

The runner discarded the drain result and polled an EOF pipe. POLLHUP returns
immediately while the child remains alive, causing repeated waitpid/drain calls.
The fix uses the existing deadline-bounded maximum 20 ms wait after confirmed
EOF, while still checking waitpid. Command timeout, output limit, post-exit
drain, process-group termination, reaping and inherited command fencing remain.
No reads, helper watchdogs, leases or recovery checks are removed.

The isolated fixed run passed in approximately 0.318 seconds with runner-thread
CPU below 5% of elapsed time. The first process-wide regression counter was
invalid in a parallel test suite: it included CPU from other test threads.
The regression now measures the synchronous caller thread using public Darwin
THREAD_BASIC_INFO, and deallocates its Mach port.

The lead full suite passes: 65 Runtime plus 21 Core tests (86 total), exit 0.
Debug and Release builds pass, both exit 0.
The reproduction does not prove ordinary pmset runs hit this edge case or
quantify an installed CPU reduction. Final clean uninstrumented 600-second
acceptance remains required under the owner’s ≤1.0% CPU / ≤75 MiB V1 gate.

The independent hidden-presentation candidate remains unmerged. Its disposable
native host missed order-out; no A/B/A installed experiment is needed or claimed.
