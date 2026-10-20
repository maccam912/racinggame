# Actual Android OS multi-contact smoke, local Build116

The installed clean-source local Build116 APK (source `8552845`, game `f762fa68`, cosmetics `f6fadc28`) runs without autodrive or synthetic race pose on the existing 2400×1080 Android phone emulator `emulator-5580`. `run.json` names its newly owned diagnostic profile. Menu navigation and driving use actual Android input events.

`inject.py` writes Linux type-B slot/tracking/position/pressure events to this emulator's observed `/dev/input/event1`. The mapper rotates raw 0..32767 axes into the observed landscape display. This follows the [Linux multi-touch protocol](https://www.kernel.org/doc/html/latest/input/multi-touch-protocol.html) and [Android touch-device mapping](https://source.android.com/docs/core/interaction/input/touch-devices). No game input/state method is invoked.

The corrected screenshots and Android `dumpsys input` snapshots establish two contacts, steering only, both again, then brake only (cooked/raw counts **2→1→2→1**). Visual review confirms the corresponding magenta pressed borders and off-center/center steering marker. Home is pressed with both contacts still down; after their release, returning opens Pause. Resume with zero contacts shows centered steering, unpressed Brake and ordinary auto-acceleration (54 mph). `summary.json` records the exact numeric assertions and APK digest.

The first two-contact attempt deliberately remains: the initial brake coordinate was outside the button, so `both-held.png` is calibration evidence only. `paused-after-release.png` also preserves a real short-lived announcer “GO” caption over Resume; this run does not fix it. Subsequent normal pause captures show the unobstructed menu.

Only the exact owned profile was pulled and moved to the named device archive after force-stop. Every injected slot is released, and final raw/cooked pointer counts are zero. Normal player profile files were not targeted. This is an emulator OS-input smoke, not ten completed human two-thumb races, physical hardware, handling balance, or a numeric performance measurement.
