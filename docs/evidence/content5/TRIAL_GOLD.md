# Gold target reachability

All 24 current car/course pairs finish valid standing-start Time Trials through the
unmodified Medium reference driver in the human slot. Real canonical static collision,
normal 60 Hz RaceSession phases, no teleports, recovery, stat edits, opponents or
saved human record are used. The [raw report](trial-gold.json) retains input hashes,
actual times, target margins, launch/landing counts and the compatibility identity.

| Course | Fastest car time | Slowest car time | Existing Gold target |
| --- | --- | --- | --- |
| palm_bay | 47.908 s | 50.946 s | 79.3 s |
| citrus_pass | 57.776 s | 58.623 s | 82.9 s |
| marina_lights | 54.991 s | 56.375 s | 78.4 s |
| redwood_run | 57.308 s | 58.418 s | 83.6 s |
| sunstone_canyon | 64.819 s | 67.111 s | 94.2 s |
| pacific_summit | 67.504 s | 69.524 s | 99.4 s |

This proves numerical reachability without changing the design's medal formula.
It does not establish human skill balance, physical input or rendered performance.
The fastest/slowest values compare these four automated runs, not a theoretical
optimum. The suite is part of the source gate on each push, with its raw JSON
uploaded by CI.
