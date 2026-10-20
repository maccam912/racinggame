# Observable graphics preparation

**Later diagnosis:** the focused Linux diagnostic on material commit `86a45a5`
showed Citrus still constructing at stage 39 of 48 when the 15-second fixture
deadline expired. Its held foreground guard was valid/false, `done` and
`graphics_error` were false, and no warmer existed yet. The original completed-
phase interpretation below was an initial hypothesis, not the cause established
by the later trace. Construction now has its own bounded 60-second software-
renderer allowance; the GPU-stage deadline remains 15 seconds. See
`docs/evidence/graphics103/` for the actual trace and follow-up.

The historical `native-held-3fps` filenames record a **3 fps launch argument**.
Client settings subsequently reset `Engine.max_fps` to 60, so those files do not
prove slow drawing. The newer explicit `--slow-construction-probe` applies the
3 fps cap after settings, records it, and requires Citrus construction to exceed
the old 15-second bound. Historical raw files remain unchanged.

Build 99's strict llvmpipe graphical gate executed sixteen fixtures, including
the corrected adaptive-resolution run. The final shader preparation fixture
failed: its log records `GRAPHICS_PREPARED` and `DRIVING_READY` before the test's
polling loop timed out waiting to observe the temporary `warming` state. It then
accessed an already-disposed warmer. Raising the deadline cannot recover a phase
that already completed. The original complete job log is retained here.

The fixture now uses each loader's existing foreground guard to hold GPU
preparation before the first draw. It can inspect the isolated viewport, inject
readback failure, cancel, and prove that the server receives no Loaded message
while submissions are held. Releasing the guard still requires real submissions,
two drawn frames and actual readback before Grid. Production code and the
15-second per-stage deadline are unchanged.

Native macOS Compatibility runs pass both at 60 fps and with a deliberately slow
3 fps cap: all six courses, failure/Retry, Cancel, and real ENet Loaded ordering.
These files record local results. Corrected strict Linux execution is pending a
new CI run; Build 99's failed parent job remains failed.
