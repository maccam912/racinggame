# Expert AI

Select **Expert** under **Quick Race → Difficulty**, **Create Room → Difficulty**,
or the host's **Room Settings → Difficulty**. Quick Race remembers the choice.
Cup keeps its fixed Medium rules.

Expert uses the ordinary car simulation and each car's own engine, traction,
boost charges and collision rules. It plans every simulation tick, carries more
speed through bends, uses a shorter steering target and countersteers lateral
slides. When centered in a sharper corner with room around it, it can use the
handbrake to drift; it releases the handbrake as slip increases or traffic closes.
Existing passing and bridge-level traffic avoidance still apply.

Hard's old baked speed cap left almost no room for catch-up. Expert uses a higher,
bounded corner-speed envelope with 160 m braking preview, while retaining the
original ramp/steep-grade limits. The nearest-human pace adjustment can raise its
corner target further when behind. Standard car top speed and race finish grace
still apply. Easy, Medium and Hard retain their previous controller behavior.

## Validation

Run the actual two-lap, eight-car contact matrix, both all-bot and with an
Expert-autopiloted human activating authority catch-up:

```sh
python3 tools/expert_acceptance.py --jobs=4
```

The broader AI matrix includes all four difficulties and checks per-car
Expert < Hard < Medium < Easy reference times:

```sh
python3 tools/bot_acceptance.py --seeds=20 --jobs=3
```

The saved three-lap Pacific Summit comparison reproduces three Hard bots
DNF against a fast reference driver; the Expert field finishes all eight cars
within 9.1 seconds, using the same 30-second finish grace. Across all 40 courses,
80 two-lap Expert races produce 640 finishers, zero DNFs and zero recoveries.

Focused checks cover braking preview, ramp limits, deliberate drift and nearby
traffic, desktop/phone controls at 150%, preference persistence, directory rules,
and exact Expert save/resume. Historical content-21 component bytes are frozen
under `tests/fixtures/content21`; old records and ghosts remain archived and
incompatible Cups and active races are preserved with continuation disabled.
Content is version 22; the packet protocol remains 10.

Automated completion and numeric pace do not establish human difficulty/feel or
physical-device performance. See the saved [evidence](evidence/expert22/README.md).
