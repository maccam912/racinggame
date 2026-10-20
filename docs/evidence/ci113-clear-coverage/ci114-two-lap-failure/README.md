# Build114 independently reproduces the old two-lap fixture limit

Actual required Linux [job](https://github.com/maccam912/racinggame/actions/runs/39408628000/job/118583549316), clean source `f9c7cc1f01c6cdf474b4fe45497222b17b91099f`, old scripted pace population.

The original .93 Switch (driver 6) is DNF when the unchanged 30-second Caldera finish grace expires. All result rows agree; both final checkpoints and the clear/wire/engine/source checks pass. Minimum clear samples **4,204**, worst clear p95 **0.0303249 m**, elapsed **612.781 s**, no cleanup issues. This independently reproduces the local two-lap failure, rather than being accepted by relaxing the gate. Raw reports/old source/log are preserved.

The later Build115 fixture narrows only driver 6's pace for multi-lap Spillway/Caldera, retaining all four production cars and every gameplay/assertion boundary. The corrected run remains separate evidence.
