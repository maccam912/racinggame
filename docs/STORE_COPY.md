# Store copy draft

This is factual copy for the current development game. Publisher identity,
support contact, privacy notice, title clearance, ratings and storefront submission
still require the owner's details. Neither official region is currently hosted.

**Title:** Pacific Rush

**Short description:** Race four original cars across six courses in a 3D arcade racer.

**Description:** Charge over steep hills, sweep through corners and fly across
the Summit crest. Pacific Rush is an original 3D
arcade racing game with four cars, eight paint colors and six courses through
beaches, citrus country, redwoods, city streets, desert and mountain scenery.

Race computer opponents in Quick Race, chase your own recorded ghost in Time
Trial, or take on the six-event Coast Cup. Five Driving School lessons introduce
the controls. Choose a chase or hood camera, tune the display and audio, and use
keyboard, gamepad or configurable Android touch controls.

Community Direct Connect supports races with up to eight players across desktop
and Android. A compatible running server is required. Regional matchmaking menus
are implemented, but the development build has no public official region service.

The development game is free and contains no payment integration.

## Screenshot capture

The six desktop and six Android images are unretouched native-export frames of
ordinary two-lap Quick Races, seven normal Medium opponents, deterministic seeds,
Near Chase, Medium graphics and the real HUD. Diagnostic AI supplies ordinary
inputs to the local player; no camera/vehicle teleport, injected race state,
overlaid artwork or simulated touch display is used. Captures happen after 1,200
actual racing ticks (20 simulation seconds), rather than a wall-clock/render-frame
deadline. Cars/paints rotate through the existing catalog.

```sh
python3 tools/capture_gameplay.py --desktop-binary '/path/Pacific Rush.app/Contents/MacOS/Pacific Rush' --out reports/store-desktop
python3 tools/capture_gameplay.py --android-serial emulator-5580 --out reports/store-android
```

The helper requires an already rooted, explicitly named owned emulator. It creates
a new diagnostic profile for each track, stops only this game, and archives only
those newly created mobile profiles. It never roots a device or clears app data.
Desktop captures run at 1920×1080; the named Android emulator runs at its actual
2400×1080 landscape resolution. Each PNG has a hash-bound JSON sidecar with actual
export identity, settings, world/output dimensions, race tick and vehicle state.
The helper rejects menus, wrong dimensions, stationary cars and missing touch HUD.
Desktop frames represent macOS; they do not prove Windows/Linux rendering.

For the owned Pixel Tablet emulator use `--android-serial emulator-5582
--expected-resolution 2560 1600` with a new output folder. The helper checks this
explicit expected size against both PNG dimensions and the game's metadata;
it does not resize the tablet output or change Android display configuration.

Use `--track=TRACK_ID` for a single-track repeat into a fresh folder. The command
line capture path requires a diagnostic profile and `--autodrive`; it never saves
these temporary camera/graphics choices into a player's settings. Existing M4
no-HUD composition references remain separate from these gameplay screenshots.

Build 86's [pre-feedback desktop/Android baseline](evidence/store-baseline86)
contains all six courses per family with exact hashes and export identity. Desktop
Summit actually reached tick 5,360 during delayed GPU readback; the other eleven
captures reached tick 1,200. That difference is retained in metadata. The current
capture code holds the genuine simulated instant before waiting for GPU readback.
These images preserve the previous presentation for comparison; final store images
will be recaptured after the owner's approved billboard/speed/verticality pass.

The newer [published Build 94 desktop/phone set](evidence/published94/) contains
all six courses per family after that pass, with actual public-package hashes
and clean embedded identities. All twelve capture tick 1,200. The separate
[local Build 94 tablet set](evidence/detail94/tablet/) retains native 2560×1600
output; tablet Palm reaches tick 1,201 as recorded. These are review candidates,
not storefront submissions. [Published-game footage](evidence/published94/footage/)
also preserves original game pace and exact package provenance.
