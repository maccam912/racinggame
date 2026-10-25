# Family polish validation, content 21

The full suite begun at `be93162` passed **227/227** commands, including 320 Gold
trials and 240 camera paths. Later UI changes were covered by focused checks;
the added six-course Relaxed field regression was run separately. See the
[command record](full-checks.json) for the exact starting commit and timings.

A 913-second native rendered run at ordinary race pace completed eight eight-car
races, cycling Palm Bay, Festival Speedway and Temple Coast. All finishes,
scene retirement, manifest stability and engine-log checks passed. Peak RSS was
740 MB; retained RSS rose 0.48% from minute 5 to minute 15, with a lower post-warmup
high-water mark. [Recorded render summary](render-soak.json).

The host recorded 51,357 racing frames: mean 16.67 ms, p95 21.94 ms, p99 23.04 ms
and maximum 33.34 ms. The optional 20 ms p95 host target was **not met**. Android
emulation and eight-client networking ran concurrently during part of the run;
these numbers do not establish minimum-hardware performance or physical-device
thermals. Audio used the Dummy driver.

Separate [packaged Android acceptance](../android-family21/README.md) passed
clean install/reinstall, native private storage, in-place upgrade, touch setup,
pause/restart and cold race recovery. The [mixed-assist UDP check](../online-family21/README.md)
passed all 16 player finishes with private assist settings preserved.

A quieter two-race follow-up (no emulator or eight-client network fixture)
recorded 11,607 racing frames: mean 16.67 ms, p95 21.79 ms, p99 22.87 ms and
maximum 34.05 ms. Some headless focused checks ran near the end. The optional
20 ms p95 target still was not met.

An uncapped native 1920x1080 Festival sweep with Retro disabled sampled 480
positions across two passes. Four-frame averages measured 1.91 ms mean, 2.13 ms
p95 and 8.25 ms maximum. This sweep omits HUD/audio/vehicle simulation and averages
four frames, so it is renderer evidence rather than a racing-frame guarantee.
These measurements do not identify a scenery bottleneck; no graphics quality or
frame-cap behavior was changed on that basis. [Follow-up measurements](performance-followup.json).

Build 165 (`a666eb4`) was downloaded from CI and checksum-verified. Its exported
macOS app passed headless native-adapter/startup checks, then rendered a real
eight-car Festival race at tick 900 with Far Chase, normal HUD and the shipped
Retro presentation. [Package report](macos-package.json), [capture](macos-festival.png),
[exported-template metadata](macos-festival.png.json). The later Quick/Trial
menu-return fix is outside this package check.

The next full suite, started at `a666eb4`, passed **229/229** commands, including
the new Next Course and six-course Relaxed regressions. The subsequent Quick/Trial
return fix passed two focused checks. [Second full command record](full-checks-next-course.json).
Live network fixture extensions are recorded separately; this is not a claim
that every later test-harness byte was present at the full run's start.
