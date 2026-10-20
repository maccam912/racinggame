# Skyline and Quarry repeated scene lifetime — pass

Nine normally paced eight-car races over 957.4 native seconds (959.43 s wrapper), alternating Skyline Splice and Quarry Switchback from the start. Both heavy worlds run before minute five. The unchanged 5–15 minute peak-growth gate passes at **2.478%**, peak RSS **666,681,344 bytes**. All loading peaks are retained. Frame p95/p99 **18.349/18.905 ms**, maximum 30.024 ms over 53,665 active race frames.

Runtime and cosmetic manifests remain exactly clean-source `958478a`, gameplay `dfb78c44` and assets `f84503f5`, throughout measurement. The working tree is dirty with docs/raw proposed course art and the explicit-course measurement fixture. Exact fixture source is retained and its native script hash matches the report. No runtime/assets changed during the run.

The explicit order is not a rerun of all eight courses and does not reclassify `../render-lifetime-initial/` as passing. It checks repeated heavier-world construction, rendering and retirement on this development Mac, Medium/60 cap, 1920×1080, Dummy audio, with other processes/emulators active. It does not establish continuous worst-track, minimum-device, human handling or physical thermal acceptance.
