# Forty-course expansion evidence

The retained ten courses and thirty additions are specified in
[the roster](../../COURSE_ROSTER_40.md). Gameplay content is 12, protocol 7,
save schema 1. Existing route definitions/bakes remain unchanged.

- `source-checks.json`: completed 191-command local gate. The earlier
  `initial-source-checks.json` retains its two failures; exact-normal and
  single-mesh deck assumptions were corrected, then checked again.
- `ai-summary.json` / `ai-fields.json`: 480 eight-car races, three difficulties,
  four reference-car choices, 3,840 finishers, no recoveries. Seeds rotate cars;
  they do not introduce stochastic behavior. Solo difficulty ordering uses the
  existing isolated flat reference fixture.
- `trials.json`: 160 legal standing-start Gold finishes, all four cars on every
  course. `cameras.json`: six real laps per course for three cameras and two
  look-back phases. These establish numeric reachability/clearance, not human
  difficulty or driving feel.
- `worlds.json`: all thirty new static worlds, five grounded/road-clear
  landmarks and three open 3D structures each; bounded sprite batches and sky
  cache. `selection-layout.json`: 80 native layouts focus the fortieth course.
- `native-references.json`: 160 native 1080p Far Chase images. The six PNGs here
  are unretouched examples; all local originals remain under `reports/`.
  The capture records its then-current cosmetic identity; subsequent changes
  corrected manifest description text only. Final identity is in package evidence.
- `billboards-native.json`: all 69 sprites render from four approach directions;
  source hashes, alpha, mipmaps and native instance bounds are checked.
- `audio.json`: actual decoded eight-engine/music/impact/voice DSP capture,
  including loop boundaries, Night and mute. Human listening and physical
  speakers remain separate. Original music/license evidence is retained in
  `assets/source/music` and packaged attribution in `assets/licenses`.
- `network-summary.json`: actual ENet/UDP race on Reactor Rift, catalog index 39,
  with 50±10 ms one-way delay and 2% loss. The two client reports retain matching
  authoritative results and presentation bounds.

`summit-summary.json`, spatial sweeps and compressed live-race reports retain
the performance comparison. The old-render fixture copies the previous road
and roadside methods verbatim from commit `373c970`. Spatial cells preserve
every roadside instance pose; road chunks preserve every triangle/UV. Native
readback and headless count checks are retained in `partitions-*.log`.

The final renderer submits about 80% fewer median primitives and 14% fewer
median draw calls in the low-shadow sweep. The eight-car race sustains 60 fps
on this Apple M5 Pro, with no frames over 33 ms after the change. Severe reported
stalls were not reproduced. Uncapped timings vary by view and shadow setting;
the pre-balloon band did not show a consistent timing improvement. This is
evidence of reduced submitted work and stable rendering on this host, not a
claim that every reported stall or other GPU has been certified.

Final focused asset/parse/native checks cover the later cosmetic metadata and
diagnostic-fixture changes after the comprehensive source run. Exported package,
remote CI and physical-device results are separate evidence boundaries.
