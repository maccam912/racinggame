# Live graphical scene-cycle evidence

`python3 tools/render_soak.py` runs the source client for at least 900 seconds,
finishing its current race before stopping. It cycles all six courses, seven
Medium opponents, normal input-provider AI for the local car, the production
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
