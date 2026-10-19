# Pacific Rush

Original colorful arcade circuit racer for desktop and Android. [DESIGN.md](DESIGN.md) is the authoritative launch specification; [docs/STATUS.md](docs/STATUS.md) separates implemented work from acceptance evidence.

Requires Python 3.14.7. The bootstrap downloads checksum-verified Godot 4.6.3 into a project-specific user cache, preserving your existing engine. No cloud account is required for offline development.

```sh
python3 tools/godot.py --editor --import --quit
python3 tools/godot.py
python3 tools/godot.py -- --drive
python3 tools/godot.py --headless -- --server --port=27020
python3 tools/bake_tracks.py --check
python3 tools/godot.py --headless --script tests/content_tests.gd
python3 tools/godot.py --headless --script tests/driving_tests.gd
python3 tools/godot.py --headless --script tests/world_tests.gd
python3 tools/godot.py --headless --script tests/progress_touch_tests.gd
python3 tools/godot.py --headless --fixed-fps 60 --script tests/slice_smoke.gd
python3 tools/check.py
python3 tools/local_race.py
python3 tools/network_integration.py --seconds 90 --latency 75 --jitter 30 --loss .03 --reconnect
python3 tools/build.py macos --number 1
```

Build targets: `linux`, `windows`, `macos`, `android` (APK), `android_aab`, `server`. Export templates download on first export. Android requires JDK 17, SDK 36/build-tools 35.0.1 and ARM64; set `JAVA_HOME` and `ANDROID_HOME`. Release-mode APK/AAB packages use a stable development keystore. Production publisher signing, store submission, Developer ID/notarization and physical-device validation remain required.

Handling and cars: `game/content/cars.json` and `game/core/vehicle_sim.gd`; course controls: `game/content/tracks.json`. Rebuild canonical routes with `python3 tools/bake_tracks.py`; do not hand-edit bakes. After gameplay changes run `python3 tools/content_hash.py`. Strict JSON schemas live in `schemas/`. Tools are pinned in `tools/toolchain.lock`. Source assets and licenses are listed in `assets/manifest.json`. Touch layout is `game/platform/touch_driving.gd`. Offline menus now expose Quick Race, Trial, Cup, School and Garage; art remains developmental. Saves use independent components under Godot's Pacific Rush user-data folder. `--profile=left` selects an isolated diagnostic profile.

`local_race.py` launches a dedicated worker and two native clients. Direct Connect accepts `host:port`; the M2 development worker starts once two clients load. Official hosted rooms and full lobbies are still M3 work. Fault fixtures use a real UDP proxy and keep resets separate from ordinary correction measurements.

Every push to main validates source/geometry, executes real-client network fault scenarios, exports all platforms, checks native package startup, and publishes a numbered development prerelease if every gate passes. These are development checkpoints, not completed launch releases.
