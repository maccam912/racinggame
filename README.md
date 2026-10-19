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
python3 tools/build.py macos --number 1
```

Build targets: `linux`, `windows`, `macos`, `android`, `server`. Export templates download on first export. Android requires JDK 17, SDK 36/build-tools 35.0.1 and ARM64; set `JAVA_HOME` and `ANDROID_HOME`. Debug APK updates use a stable development keystore; production signing, AAB/store packaging, Developer ID/notarization and physical-device validation remain required.

Handling and cars: `game/content/cars.json`; course controls: `game/content/tracks.json`. Rebuild canonical routes with `python3 tools/bake_tracks.py`; do not hand-edit bakes. Tools are pinned in `tools/toolchain.lock`. Source assets and licenses are listed in `assets/manifest.json`.

Every push to main runs validation and publishes a numbered development prerelease with desktop, Android and server artifacts when all export jobs pass. These are development checkpoints, not completed launch releases.
