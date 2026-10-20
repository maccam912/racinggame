# Pacific Rush

Original colorful 3D arcade circuit racer for desktop and Android. [DESIGN.md](DESIGN.md) is the authoritative launch specification; [docs/STATUS.md](docs/STATUS.md) separates implemented work from acceptance evidence.

Four cars race ten distinct arcade courses: coastal highway, sharp downtown
blocks, orchard and forest dirt rallies, a desert jump stadium and a mountain
rollercoaster. Skyline Splice adds a layered harbor crossing, Quarry Switchback
linked hairpins, Spillway Sprint a trefoil waterworks and Caldera Crosscut a
neon volcanic moon beneath a ringed planet. [Course maps and elevation profiles](docs/evidence/arcade-tracks/layouts.svg)
and [native views](docs/evidence/arcade-tracks/lineup.jpg) show the current lineup.
Original rocks, logs, waterfalls, painted travel signs and
illustrated foliage mix with 3D cars, buildings, bridges and crest structures.
The interface uses original arcade lettering and glossy chrome; car paint,
glass and dry paving have authored surface detail. Download numbered desktop/Android development
packages from [Releases](https://github.com/maccam912/racinggame/releases).
[The 32-row acceptance index](docs/ACCEPTANCE.md) records verified scope and open
human, hosting and publisher checks. Phone/tablet development checks use emulators;
physical-device testing is optional owner follow-up.

Requires Python 3.14.7. The bootstrap downloads checksum-verified Godot 4.6.3 into a project-specific user cache, preserving your existing engine. No cloud account is required for offline development.

```sh
python3 tools/native_build.py host
python3 tools/godot.py --headless --editor --import --quit
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
python3 tools/save_acceptance.py
python3 tools/local_race.py
python3 tools/network_integration.py --seconds 160 --laps 2 --latency 75 --jitter 30 --loss .03 --reconnect
python3 tools/build.py macos --number 1
```

`tools/check.py` retains a separate `reports/checks-<id>/` folder for each run,
complete merged logs for every command and an atomic partial/final summary.
`reports/checks.json` is the latest snapshot; an unfinished run cannot be green.
Timeouts and interruption retain output and stop that invocation's owned process
group on macOS/Linux. Windows source runs retain their direct-child cleanup
scope. CI uploads the full source-check folder, including failures.

Build targets: `linux`, `windows`, `macos`, `android` (APK), `android_aab`, `server`. Export templates and checksum-pinned native SDK/SCons dependencies download on first export. Native adapters build on their target OS (Android can cross-build); Linux builds require `libsecret-1-dev`, `libxrandr-dev` and `pkg-config`. CI builds and merges all adapters before export. Android requires JDK 17, SDK 36/build-tools 35.0.1 and ARM64; set `JAVA_HOME` and `ANDROID_HOME`. Release-mode APK/AAB packages use a stable development keystore. Production publisher signing, store submission and Developer ID/notarization remain owner release inputs.

Android exports also compile the project-owned [audio-focus/network bridge](docs/ANDROID_SERVICES.md) against the pinned engine library and verify its manifest/DEX inclusion. Mobile [offline recovery](docs/OFFLINE_RESUME.md) and [foreground/adaptive resource policy](docs/MOBILE_RUNTIME.md) have separate source, native-render and emulator evidence in the status report.

Track Loading now [renders required graphics variants](docs/SHADER_LOADING.md) before Grid or online Loaded, with foreground waiting, Retry and Cancel. Current [Build 116 evidence](docs/evidence/release116/) includes all ten actual Linux GPU-prepared worlds and strict native rendering, with full release gates passing. Earlier construction-time failures and their correction remain in [the graphics follow-up](docs/evidence/graphics108/).

Player and room names use portable [Unicode 16 grapheme rules](docs/UNICODE_NAMES.md), checked against the same 1,093 official vectors as the directory. The Android/native eight-player race-and-rematch fixture is documented there. Shared [font fallbacks and whole-grapheme editing](docs/TEXT_RENDERING.md) keep accepted emoji names visible in exported games.

Handling and cars: `game/content/cars.json` and `game/core/vehicle_sim.gd`; course controls: `game/content/tracks.json`. Full-lock steering above 15 m/s starts a controlled slide; ease off or countersteer to catch it. The Slide button also starts a drift. Run `tests/steering_drift_tests.gd` for all-car slide/recovery/snapshot coverage. Rebuild canonical routes with `python3 tools/bake_tracks.py`; do not hand-edit bakes. After gameplay changes run `python3 tools/content_hash.py`. Strict JSON schemas live in `schemas/`. Tools are pinned in `tools/toolchain.lock`. Source assets and licenses are listed in `assets/manifest.json`. Touch layout is `game/platform/touch_driving.gd`. Offline menus now expose Quick Race, Trial, Cup, School and Garage; art remains developmental. Saves use independent components under Godot's Pacific Rush user-data folder. `--profile=left` selects an isolated diagnostic profile.

**Online → Host by Code / Join by Code** now provides [Iroh multiplayer](docs/IROH.md)
using the same four-character discovery service as Mega Chamomile. The host runs
the existing eight-player authority inside its foreground game; no regional
deployment is needed. Share the lobby code, choose Ready and race. Codes expire
after ten minutes and can be replaced. Leaving or Android backgrounding closes a
hosted room. Source builds require Rust 1.98.1; `tools/native_build.py host` builds
the locked Iroh extension alongside the existing OS adapter.

`local_race.py` launches a dedicated worker and two native clients. Direct Connect accepts `host:port`; the community worker opens a persistent lobby with Ready/Start, bot fill, car/track choices and rematches. The local Go directory allocates ticket-required workers; see `services/directory/README.md` and run `python3 tools/directory_integration.py` with Go 1.27.0 installed. The HTTPS client, full online menu path and native identity stores have integration gates; official hosted regions remain deployment work. Both official URLs in `game/content/regions.json` stay blank until deployment. An explicit `--directory-url=https://…` selects Test Region; `--directory-ca=/path/to/test-root.crt` trusts that CA for these requests only. Run `python3 tools/directory_client_integration.py` for the client/auth/allocator/private-code fixture with an isolated test CA; add `--menu` for the complete menu path or `--menu --visual` for native 150% screenshots. Fault fixtures use a real UDP proxy and keep resets separate from ordinary correction measurements.

The [Linux server bundle](docs/SERVER_PACKAGE.md) includes the matching operator CLI, dependency licenses and runbooks. [OCI hosting](docs/CONTAINER_HOSTING.md) adds gated image/recovery checks and an operator region example. Managed workers report [tick percentiles, current native RSS and capacity headroom](docs/SERVER_PERFORMANCE.md) through authenticated private heartbeats. [Supervisor recovery and rollout](docs/SUPERVISOR_LIFECYCLE.md) retain active races, drain old pools and share bounded capacity. [Database backup and restore](docs/DIRECTORY_BACKUPS.md) preserve identities while clearing stale leases. `python3 tools/soak_acceptance.py --clear-road-spacing` runs the separate eight-client, ten-race impaired-network and 5–15 minute memory fixture.

Every push to main builds all platform packages and the Linux OCI image, then
publishes a numbered development prerelease. Pull requests build the same
artifacts. Package checksums, icons and Android signatures remain part of the
build. These are development checkpoints, not completed launch releases.

Run **Actions → Extra tests and soak → Run workflow** for source/content checks,
the complete ten-course AI matrix, network and Iroh integration, rendering/audio,
native package and save/store checks, directory/container recovery, and the
ten-race impaired network/memory soak. This separate
[`workflow_dispatch` workflow](.github/workflows/extra-tests.yml) runs only when
requested; it builds matching packages, retains test evidence even on failure,
and does not publish a release. The regular build and manual tests share
[`packages.yml`](.github/workflows/packages.yml). From the CLI:

```sh
gh workflow run extra-tests.yml
```

Cosmetic changes keep their own asset identity. [Foliage](docs/BILLBOARD_ART.md), [painted signs](docs/ROADSIDE_POSTERS.md),
[3D scenery detail](docs/SCENERY_DETAIL.md) and [content-5 tuning](docs/ARCADE_TUNING.md)
have saved sources and evidence. `python3 tools/render_soak.py` separately measures
live catalog graphical scene lifetimes on the current desktop; its wall-clock
frame report is distinct from fixed-frame video recording and minimum-device
performance acceptance.

`python3 tools/mixed_android_acceptance.py --serial emulator-5584 --number 95
--races 10 --laps 3 --seconds 2400 --impaired` runs an installed release APK
against seven native clients through independent 50±20 ms / 1% loss UDP proxies.
Use only an explicitly selected, already rooted test emulator. It preserves
unrelated profiles, records exact authority/Android/native result agreement,
streams logs across buffer rotation and samples Android process RSS. Its output
is automated emulator evidence, separate from human touch or hardware performance.

The four original car meshes have explicit 35/90 m LODs, a shared 1024² atlas, all eight paint choices and independently animated wheels. Editable Blender source and regeneration instructions are in [assets/source/README.md](assets/source/README.md). Run `python3 tools/asset_hash.py` after changing cosmetic exports; this identity is separate from gameplay content and appears in build metadata. Six original scenery kits now supply all 30 named landmarks, with shared vegetation, neighborhood buildings, road furniture and rendered course postcards. The 48 original audio assets include six course compositions, menu/results music, four engine profiles, effects and fixed synthetic announcer cues. Run `python3 tools/audio_acceptance.py --capture` (ffmpeg required) for the actual eight-engine mix gate, or add `--native-output` for a rendered final-output/Master-mute check. Bounded smoke/dust/sparks/skid batches, contact opacity, recovery transitions and camera feedback are implemented. Sixty-two original editable interface icons, real Garage stat bars, car-specific medals and responsive selection panes are implemented. Authoritative lap clocks, saved-ghost live delta and bounded visible rival labels complete the main racing HUD. The dated status report records current release checkpoints and remaining owner usability, hosting and publisher inputs; physical-device testing is optional owner follow-up. Native save barriers, profile ownership and deletion recovery are documented in [docs/SAVE_DURABILITY.md](docs/SAVE_DURABILITY.md).


Touch layout editing is under Settings → Touch → Edit Layout on Android. Drag the outlines, or focus one and press Confirm to move it with keyboard/controller directions; Back stops moving it. Save validates target sizes, safe margins and overlap. Preview runs a separate 30-second practice drive and returns to the draft. Cancel preserves saved positions, and Restore Layout resets only the current device/orientation/control profile. Layout geometry cannot be changed during an online race.

The optional native platform extension supplies macOS Keychain, Windows DPAPI and Linux Secret Service primitives. Run `python3 tools/native_store_ci.py` to test a new random test entry and delete it afterward. Hosted CI isolates its macOS keychain and Linux D-Bus session. Android uses non-exportable AES/GCM keys and atomic ciphertext files excluded from backup. Guest identity storage, its worker service and online directory menus are implemented; official region operation remains unconfigured. No plaintext identity fallback is provided.

### Binary assets and Git LFS

Install Git LFS before cloning, then run `git lfs install` and `git lfs pull`.
All binary asset types (including historical screenshots, videos, Blender/glTF,
audio, fonts, icons and replay fixtures) are stored in LFS. CI checkouts fetch
LFS content. Text sources, SVGs and JSON remain ordinary Git files.

The October 20, 2026 migration rewrites main and release-tag history. Existing
clones should save local work and re-clone; do not merge the old history back
into main. Release download artifacts are unchanged. For old tag builds, run
`git lfs pull` after checkout because historical workflows predate LFS setup.
