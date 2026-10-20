# Observable graphics preparation

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
