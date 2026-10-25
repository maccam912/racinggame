# Expert AI validation — October 25, 2026

Local macOS/arm64, Godot 4.6.3, working tree based on `5631953`.
Gameplay content 22, protocol 10, hash
`6c2a0502f9288f19fcdf56209893f3f1f30b2e39390e12021d4fc9f8f2e49ade`.

- [Full catalog](field-summary.json): 80 two-lap contact races, 640 finishers,
  **zero DNFs and zero recoveries**, 318,503 vehicle ticks in active drift.
  Each of the 40 real baked/collision routes ran once with all eight cars as
  Expert bots and once with seven Experts plus an Expert-autopiloted human
  enabling authority race roles and catch-up. One seed/reference car per case;
  the fixed bot roster includes the other car types. No random AI variation.
- **Three-lap DNF reproduction:** with the same Expert-autopiloted reference
  car, seed and contact rules on Pacific Summit, [Hard](hard-three-lap.log)
  finishes 5/8 cars and leaves three bots DNF at finish grace. Changing the
  opponents to [Expert](expert-three-lap.json) finishes **8/8 with no recoveries**,
  all within 9.1 seconds. Finish grace remains the normal 30 seconds. The
  baseline failure is expected; the engine wrapper stops on the reported DNFs.
- [Flat reference](flat-reference.json): all eight cars finish at all four
  difficulties; every car satisfies Expert < Hard < Medium < Easy. Expert lap
  times are **6.0–12.5% shorter than Hard**. This fixture-only Palm Bay geometry
  is flattened, with ramps/banking removed and contact disabled; shipped roads
  are unchanged.
- [38 focused GDScript suites](focused-checks.json) pass: controller inputs,
  braking preview, deliberate handbrake in clear space, traffic inhibition,
  ramp limits, existing driving/drift/boost, Quick Race persistence, room rules,
  exact Expert save/resume, and historical content-4 through content-21 bytes.
- [Expert UI](expert-ui.log), [all shipped script compilation](source-compile.log)
  and [content contracts](content-tests.log) pass separately: **41 GDScript
  suites total**. The UI check selects Expert in Quick Race, Create Room and
  host settings, sends the host rule and renders bot labels on desktop and
  a phone-sized viewport at 150% scale.
- [33 Python tests](python-tests.log), `go test ./...` in `services/directory`,
  strict JSON content validation, gameplay/asset hash checks and `git diff --check`
  pass. The directory test includes all four legal difficulty values and
  rejects value 4.

Reproduce field evidence with `python3 tools/expert_acceptance.py --jobs=4`.
For the full four-difficulty/20-seed matrix, use `tools/bot_acceptance.py`;
that larger matrix was not run here. The new frozen content-21 files were
captured before modifying gameplay and have SHA-checked preservation coverage.

This is automated local pace/completion evidence. Human difficulty and driving
feel, physical Android performance, real multiplayer sessions, CI and publication
were not tested by these runs.
