# Initial two-lap fixture: retained finish-grace failure

Exact clean local runtime source `f9c7cc1f01c6cdf474b4fe45497222b17b91099f`; game/assets remain Build112 `f762fa68` / `15a71230`. Command: `python3 tools/soak_acceptance.py --port 27510 --races 2 --laps 2 --seconds 840 --minimum-seconds 0 --tracks spillway_sprint,caldera_crosscut --trace-driving`.

**Failure:** the original slowest test driver (index 6, Switch, target pace .93) exceeds the unchanged 30-second finish grace on the second, Caldera race. All 16 rows agree, but only 15 are successful finishes; the Caldera DNF remains rejected. Clear coverage now passes with a minimum **3,870** samples per client/race and worst p95 **0.0307725 m**. Final gates, packet/wire/error/source checks pass, no cleanup issues; 611.246 seconds. The complete raw reports and old fixture sources remain untouched.

This motivates a course/lap-specific scripted pace adjustment for the long-course coverage fixture, not a production handling, AI, finish-grace or assertion change. The original one-lap fixture and classic three-lap soak retain their prior pace population. Build114 was dispatched with this initial two-lap procedure and is not claimed successful.
