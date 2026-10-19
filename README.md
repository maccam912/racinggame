# Pacific Rush

Original colorful 3D arcade circuit racer for desktop and Android. [DESIGN.md](DESIGN.md) is the authoritative launch specification; [docs/STATUS.md](docs/STATUS.md) separates implemented work from acceptance evidence.

Requires Python 3.14.7. The bootstrap downloads checksum-verified Godot 4.6.3 into a project-specific user cache, preserving your existing engine. No cloud account is required for offline development.

```sh
python3 tools/native_build.py host
python3 tools/godot.py --editor --import --quit
python3 tools/godot.py
python3 tools/godot.py -- --drive
python3 tools/godot.py --headless -- --server --port=27020
python3 tools/bake_tracks.py --check
python3 tools/godot.py --headless --script tests/content_tests.gd
python3 tools/godot.py --headless --script tests/driving_tests.gd
python3 tools/godot.py --headless --script tests/world_tests.gd
python3 tools/godot.py --headless --script tests/progress_touch_tests.gd
python3 tools/godot.py --headless --max-fps 60 --script tests/slice_smoke.gd
python3 tools/check.py
python3 tools/local_race.py
python3 tools/network_integration.py --seconds 90 --latency 75 --jitter 30 --loss .03 --reconnect
python3 tools/build.py macos --number 1
```

Build targets: `linux`, `windows`, `macos`, `android` (APK), `android_aab`, `server`. Export templates and checksum-pinned native SDK/SCons dependencies download on first export. Native adapters build on their target OS (Android can cross-build); Linux builds require `libsecret-1-dev`, `libxrandr-dev` and `pkg-config`. CI builds and merges all adapters before export. Android requires JDK 17, SDK 36/build-tools 35.0.1 and ARM64; set `JAVA_HOME` and `ANDROID_HOME`. Release-mode APK/AAB packages use a stable development keystore. Production publisher signing, store submission, Developer ID/notarization and physical-device validation remain required.

Handling and cars: `game/content/cars.json` and `game/core/vehicle_sim.gd`; course controls: `game/content/tracks.json`. Rebuild canonical routes with `python3 tools/bake_tracks.py`; do not hand-edit bakes. After gameplay changes run `python3 tools/content_hash.py`. Strict JSON schemas live in `schemas/`. Tools are pinned in `tools/toolchain.lock`. Source assets and licenses are listed in `assets/manifest.json`. Touch layout is `game/platform/touch_driving.gd`. Offline menus now expose Quick Race, Trial, Cup, School and Garage; art remains developmental. Saves use independent components under Godot's Pacific Rush user-data folder. `--profile=left` selects an isolated diagnostic profile.

`local_race.py` launches a dedicated worker and two native clients. Direct Connect accepts `host:port`; the community worker opens a persistent lobby with Ready/Start, bot fill, car/track choices and rematches. The local Go directory allocates ticket-required workers; see `services/directory/README.md` and run `python3 tools/directory_integration.py` with Go 1.27.0 installed. The HTTPS client, full online menu path and native identity stores have integration gates; official hosted regions remain deployment work. Both official URLs in `game/content/regions.json` stay blank until deployment. An explicit `--directory-url=https://…` selects Test Region; `--directory-ca=/path/to/test-root.crt` trusts that CA for these requests only. Run `python3 tools/directory_client_integration.py` for the client/auth/allocator/private-code fixture with an isolated test CA; add `--menu` for the complete menu path or `--menu --visual` for native 150% screenshots. Fault fixtures use a real UDP proxy and keep resets separate from ordinary correction measurements.

Every push to main validates source/geometry/assets, executes real-client network fault scenarios, renders the original car/ghost shaders in a Linux graphics context, exports all platforms, checks native package startup, and publishes a numbered development prerelease if every gate passes. These are development checkpoints, not completed launch releases.

The four original car meshes have explicit 35/90 m LODs, a shared 1024² atlas, all eight paint choices and independently animated wheels. Editable Blender source and regeneration instructions are in [assets/source/README.md](assets/source/README.md). Run `python3 tools/asset_hash.py` after changing cosmetic exports; this identity is separate from gameplay content and appears in build metadata. Six original scenery kits now supply all 30 named landmarks, with shared vegetation, neighborhood buildings, road furniture and rendered course postcards. The 48 original audio assets include six course compositions, menu/results music, four engine profiles, effects and fixed synthetic announcer cues. Run `python3 tools/audio_acceptance.py --capture` (ffmpeg required) for the actual eight-engine mix gate, or add `--native-output` for a rendered final-output/Master-mute check. Bounded smoke/dust/sparks/skid batches, contact opacity, recovery transitions and camera feedback are implemented. Sixty original editable interface icons, real Garage stat bars, car-specific medals and responsive selection panes are implemented. Race HUD/interface work continues under M4.


Touch layout editing is under Settings → Touch → Edit Layout on Android. Drag the outlines, or focus one and press Confirm to move it with keyboard/controller directions; Back stops moving it. Save validates target sizes, safe margins and overlap. Preview runs a separate 30-second practice drive and returns to the draft. Cancel preserves saved positions, and Restore Layout resets only the current device/orientation/control profile. Layout geometry cannot be changed during an online race.

The optional native platform extension supplies macOS Keychain, Windows DPAPI and Linux Secret Service primitives. Run `python3 tools/native_store_ci.py` to test a new random test entry and delete it afterward. Hosted CI isolates its macOS keychain and Linux D-Bus session. Android uses non-exportable AES/GCM keys and atomic ciphertext files excluded from backup. Guest identity storage and its worker service are implemented; online directory menus remain in progress. No plaintext identity fallback is provided.
