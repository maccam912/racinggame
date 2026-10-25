# Packaged Android family setup

Build 159 (`be93162`) passed clean install, first launch, native private-file and
protected-key cold-read checks, uninstall removal and reinstall on a fresh owned
Android 15 / API 35 arm64 emulator. Wi-Fi and mobile data were disabled to exercise
the offline path. The unrelated existing emulator was untouched.

Build 161 (`0e8a0a5`) then passed in-place upgrade with the same signer and UID,
all 30 existing files byte-for-byte preserved before launch, and the installed APK
hash matching the downloaded CI artifact. Both APK checksums were verified.

Using actual Android touch input, the saved Smooth filter and Palm Bay selection
survived cold launch. The Relaxed button was visible before scrolling; applying it
saved 75% sensitivity, Strong steering, corner braking, turn hints and both auto
acceleration settings. The race used one lap, three Easy rivals and no car contact.
Garage pictures, the event selector and the race HUD were visually inspected.
Pause, Restart, Home/return and force-stop/cold-resume paths worked; Android Godot
logs contained no script or engine errors during these interactions.

[Clean-install report](install.json), [upgrade report](update.json),
[interaction record](interaction.json). Captures: [garage](garage.png),
[setup](setup.png), [race](race.png), [cold resume](resume.png).

This is emulator acceptance of development-signed builds. It does not establish
physical touchscreen feel, child playability, device thermals or Play Store/public
signing readiness. Build 161 CI completed successfully, including all six exports,
native adapters, containers and publication.

## Build 167: Next Course on Android

Actual garage/paint/preset/Start/Next taps complete Palm Bay then Saltflat Velocity
in the exported APK. Both results are saved; the yellow Needle, Smooth filter,
one lap, three Easy rivals, no contact and all Relaxed preferences are retained.
Diagnostic autodrive supplies race inputs, so this establishes menu, continuation
and persistence behavior rather than child handling. No engine errors occurred.
[Checks and package identity](next-course.json), [Relaxed setup](next-relaxed.png),
[next loading screen](next-loading.png), [second result](next-results.png).
