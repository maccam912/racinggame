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
