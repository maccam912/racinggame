# Live graphical scene-cycle evidence

`python3 tools/render_soak.py` runs the source client for at least 900 seconds,
finishing its current race before stopping. By default it cycles the current
ten-course catalog; `--tracks` selects an explicit repeated course order. It uses
seven Medium opponents, normal input-provider AI for the local car, the production
loading/warm-up path and the native HUD. A random diagnostic profile isolates the
run. `--seconds 1` is a smoke run that still finishes one ordinary race.

The desktop is 1920×1080 Medium with a 60 fps cap and VSync disabled. Frame
intervals use wall-clock microseconds between `frame_post_draw` callbacks during
Racing/Grace, including OS scheduling. They do not use the engine's smoothed
simulation delta or fixed-frame Movie Maker output. The wrapper samples native
RSS once per second, preserves logs and partial reports on failure, checks
unchanged gameplay/asset identities and stops only its own child process.
Scene/loading transition memory peaks remain in the report.

The [first complete run](evidence/graphical-soak/summary.json) on this Apple M5 Pro
finishes **12 races / 96 cars**, with no DNF or engine/shutdown error, in
902.82 seconds. Actual racing draw intervals have **18.497 ms p95**, **22.324 ms
p99** over 44,699 samples. There are **four intervals over 33 ms**, with a maximum
**1,772.630 ms**; those samples remain in the distribution. Other applications
and Android emulators were active, including a new emulator boot during this run.
During the second Redwood load the window temporarily stopped drawing; raising
it restored drawing. That loading interval is separate from the racing frame
population. It is not a cold-load timing result.

Native RSS peaks at **688,226,304 bytes**. The comparable cycle high-water mark
grows **2.8803%** between the five-/fifteen-minute windows; retained endpoint RSS
falls 33.21%. These measurements pass this host's lifetime/memory guards. They
do not establish minimum Windows/M1/Intel hardware performance, a continuous
worst-track run, GPU memory, physical Android or thermal behavior. Physical
checks are optional owner follow-up. The 32-row [acceptance index](ACCEPTANCE.md)
keeps PERF-01 partial.

The short initial prototype used simulation delta and is excluded from frame
timing evidence. The first long attempt was interrupted to correct that metric;
its failed report is retained in the ignored reports folder. The completed run
uses the wall-clock fixture hash recorded in its raw JSON. Its wrapper predates
the final automatic QA-profile archival refinement; the completed run's unique
profile was separately archived after exit. Current helpers retain only their
own newly named profiles with their reports.

The final wrapper also passes a separate one-race
[automatic-profile-archive smoke](evidence/graphical-soak/profile-archive-smoke.json),
with `owned_profile_archived: true`. That follow-up verifies its cleanup path;
the original fifteen-minute report remains unchanged.

## Later content-8 runs

The [full catalog-cycle run](evidence/city108/render-lifetime-initial/)
completes 12 races but **fails** the unchanged 5% post-warm-up growth guard at
**9.343%** (peak RSS 815,464,448 bytes). Its first full eight-course cycle takes
638 seconds, beyond the five-minute warm-up; the actual failed verdict remains.
A separate explicit [Skyline/Quarry repeat](evidence/city108/render-lifetime-heavy/)
**passes** nine complete eight-car races in 957.4 native seconds, with peak RSS
**666,681,344 bytes**, growth **2.478152%**, racing p95/p99 **18.349/18.905 ms**.
Both heavy worlds are seen before the five-minute baseline. This does not
reclassify the earlier failure or establish all-catalog/minimum-hardware limits.
The current quiet fixture uses the production mixer/resource path with Dummy
audio output; its exact source and every scene/loading memory peak are retained.

The clean-source [content-9 Caldera/Spillway repeat](evidence/content9/render-lifetime-new-courses/)
passes seven complete eight-car races in 1,042.6 native seconds, with peak RSS
**761,806,848 bytes**, growth **1.855422%**, and racing p95/p99
**18.336/19.048 ms** across 59,260 samples. Both new worlds load before the
five-minute baseline. The report identifies clean source `95660b7` and exact
cosmetic hash `1fe44b97`; later cosmetic work does not change that pairing.
Other fixture processes were active during warm-up. Full loading peaks and
all draw intervals remain, including one 34.713 ms maximum. This is a
course-specific host lifetime result, with the same hardware boundaries above.


## Explicit emulator process-memory acceptance

The installed-APK mixed-client helper accepts `--check-memory` for an explicitly
selected route/lap population. The existing ten-race/three-lap procedure still
enforces it automatically. Reports identify the actual selected canonical course
IDs and lap count; the limits remain **1 GB process VmRSS** and **at most 5%**
repeated-cycle peak growth across minutes 5–15, including observed loading peaks.
Complete warm-up/window coverage is required, and whole-run RSS cap checks also
include samples after minute 15. Separate GPU/emulator-host allocations are
unmeasured; these are independent from the native desktop figures above.
[Exact helper regressions and preserved initial interruption](evidence/emulator-memory-scope/).
