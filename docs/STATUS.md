# Implementation status

Owner scope update, 19 October 2026: use phone/tablet **emulators only** for this
implementation. Physical checks in historical checkpoints are optional owner
follow-up, not blockers. Human usability, real thermal behavior and other hardware
remain unmeasured; emulator evidence retains its actual label. The latest owner feedback
authorizes physics tuning for manic arcade speed, stronger hills/drops and dramatic
set pieces, superseding the earlier exact-physics choice. Original illustrated
billboard decorations are approved. The owner explicitly leaves official regions
unconfigured in development releases for now. DESIGN.md v1.6 records this scope.

Latest release: **Build 94**, all 18 desktop/Android/server files plus the tested OCI image. Current source work finishes M5 robustness gates and prepares the specified M6 release assets; owner-operated publishing/regions remain open; physical hardware is optional owner follow-up.

The design, including the latest owner decisions, remains the launch contract. Historical checkpoint notes retain their original measurements and open gates; the owner update above supersedes physical-device blockers.

Current work is the owner-approved content-5 handling/elevation revision and its
M5 regression checks. M0–M4 source features and release infrastructure exist;
current validation is described by dated checkpoints below. M6 packages, store
materials and operator tooling are being prepared. Official hosted regions,
publisher identity/signing and human handling review remain separate owner inputs.
Historical references to physical-device gates are superseded by the emulator-only
owner decision above.

## M0 — toolchain and contracts

- Godot 4.6.3 Standard, Compatibility renderer, GodotPhysics3D, 60 Hz.
- Four car definitions, six canonical 2 m route bakes, AI target-speed lines, ordered gates, safe recovery poses, versioned rules.
- Route length/radius/grade/start-region and nonadjacent-section checks pass in the canonical Python bake.
- Minimal client and headless UDP worker startup; Linux/Windows/macOS-universal/Android ARM64/server export presets.
- GitHub Actions validates bakes and shared resources, exports all platforms, and publishes a numbered prerelease on each main push.

Local macOS universal, release-mode Android ARM64 APK and development-signed AAB exports succeed. The exported macOS package passes native headless startup, and two native graphical clients render the 3D race. A disposable Pixel 7 profile / Android 15 ARM64 emulator installs and renders the APK; landscape-only orientation was corrected from that check. No physical Android device is attached. Caddy is pinned by image digest and binary checksum. The regional directory now runs locally with authenticated allocated workers; neither hosted region is deployed.

## M1 — driving slice

- Pure shared 60 Hz controller: steering/yaw filters, ground support, acceleration/braking/reverse, drift/grip recovery, surface grip/drag, gravity and landing.
- Palm Bay graybox road and continuous barrier collision from the canonical bake, original editable procedural Comet, palms, sea, gantry and road furniture.
- Near/Far/Hood cameras, look-back, dynamic vertical FOV and Reduce Motion.
- Keyboard, analog gamepad and independent multitouch slider/brake/handbrake/recovery; offline pause with three-second resume safety countdown.
- Ordered swept gates, sub-tick finish, lap count, wrong-way detection, last-valid-gate recovery freeze and ghost timers.
- Numeric tests: Comet 0–100 km/h **2.300 s**, 100–0 **20.806 m**; drift restores grip in 0.40 s; repeated 60-second fixture agrees within 2 cm.
- Engine collision fixture: 109 sustained scrape contacts; first tangential speed 37.058 m/s, final 33.458 m/s; no wall penetration beyond 5 cm. Five-pointer touch ownership/cancellation and skipped/reverse gate fixtures pass.
- Headless full-scene smoke verifies real action input moves the car on baked collision and pause/resume freezes position/timer correctly.

- Straight full-width jump fixture at 30/45/60 m/s: one launch and one safe landing per run. The explicit 0.18 s launch lockout plus ordinary ground snap produces **0.20 s** airborne in this fixture, shorter than the illustrative 0.35 s in §11.6. The explicit rule is preserved; this discrepancy needs a documented design/feel resolution before launch.

Pending M1 gates: physical phone driving, human cornering/feel playtest and all camera-collision edge cases. Scripted behavioral reference videos are recorded in the later checkpoint below. Recovery fades and final visuals remain M4 work; graybox references remain clearly identified.

## M2 — dedicated networking risk slice

- Dedicated authoritative 60 Hz shared RaceSession; client inputs only, ordered gates, bounded car contact and immutable sub-tick standings.
- Raw ENet channels: reliable session/results, 30 Hz redundant six-frame inputs, 20 Hz snapshots, 2 Hz clock probes. Full eight-car snapshot was **575 bytes** at the M2 checkpoint (M3 protocol 2 extends it to **727 bytes**), input batch **82 bytes**.
- Quantized prediction, 180-tick input history, authoritative restore/replay, separate 0.12 s visual correction half-life, 100 ms remote interpolation and capped 150 ms extrapolation.
- Missing-input neutralization, uint32 sequence wrap, malformed/overflow rejection, eight-seat cap, 20-second reconnect reservation and bot takeover.
- Direct Connect validates host/port (including bracketed IPv6) and labels the community server. M2 worker auto-starts when two clients load; full ready/lobby flow remains M3.
- Real UDP proxy tests impair ENet handshakes, ACKs and reliable packets as well as racing datagrams: **75 ms delay per direction, ±30 ms jitter per direction, 3% random loss**. Added round-trip delay is 150 ms; observed RTT also includes frame/poll scheduling.
- Complete Palm Bay race plus five-second disconnect/reconnect: original slot retained; both clients receive exactly equal server standings/finish times; moving clear-road samples 1,147/1,288, p95 corrections 0.0101/0.0098 m.
- 340-second alternating side/rear fixture: **84 distinct contact episodes**, 1,075/1,224 contact correction samples, p95 **0.906/0.826 m** (limit 1.5 m). Reset transitions are explicitly tagged/excluded; moving clear-road p95 remains below 0.01 m. See [contact evidence](evidence/m2-udp-contact.json) and [race/reconnect evidence](evidence/m2-udp-race-reconnect.json).
- Source contracts/numeric/scene/race/contact/jump suites pass. CI now gates publishing on these suites, faulted network runs, six exports, and native package startup on Linux, Windows, macOS ARM64/Intel and Linux server.

Android-versus-native-macOS cross-play also completes with identical authoritative standings and sub-tick times using the installed Android 15 ARM64 emulator APK: [cross-play evidence](evidence/m2-android-emulator-crossplay.json). This is not a physical-device result.

The first Linux CI reconnect run exposed stale pre-disconnect input replay. Reconnect now clears that history, restores the server's current bot-controlled state, resets the sequence from its acknowledgement, and honors the future control tick. Full reconnect restores are measured separately from ordinary driving corrections; the large restore after five seconds away is retained in evidence rather than averaged away.

Pending M2 gates: physical-device network tests, adversarial security fault matrix and broader correction/performance soak. Official ticket-required directory workers are M3 work; current tested service mode is explicitly community/direct-guest.

## M3 — offline modes and persistence checkpoint

- First-run name/units/motion preferences, shared four-car/eight-paint Garage, exact Main Menu inventory, six-track selection, configurable Quick Race and standing-start Time Trial.
- Quick Race uses up to seven bots, mixed car definitions, contact toggle and complete standings. Human grid slot is fifth when available. Finishers continue at reduced AI speed until results; the hard cap now ends at exactly 600 seconds.
- Coast Cup keeps its car/roster, six event seeds, completed results and points between launches; later grids reverse championship standings. No mid-event result or restart button advances the cup.
- Five noncompetitive Driving School objectives with fixed Palm Bay spawns, temporary turn cones, input demonstration, Retry and Skip. Human lesson usability is not yet established.
- Component saves use versioned JSON envelopes, temporary replacement, good backups, corrupt-file preservation and read-only handling of future versions. Result/stat journals are idempotent across interrupted writes. Native fsync and interprocess locking remain M5 work.
- Trial ghosts use checksummed PRGH v1 transforms at 20 Hz plus the exact sub-tick final sample, and a 2 MiB limit. A real shared-controller trial finished in **67.223876227 s**, recorded **1,346 samples**, and cold-loaded the matching record/ghost. Medals use the specified length-based thresholds.
- Desktop/mobile settings are separate. The tabs expose the specified value rows; working preferences include units, camera/FOV/motion, input deadzone/sensitivity/auto acceleration, UI scale/contrast, frame cap, MSAA/render scale, brightness/shadows and master volume. Display changes have a 15-second Keep/Revert flow. Per-channel audio and adaptive quality are still pending; touch-layout editing is covered below. Keyboard/gamepad remapping is covered below. Touch manual throttle, steering style, handedness, size and opacity are covered by the later controls checkpoint.
- Bundled Barlow fonts/OFL licenses and external English text catalog. Display names normalize to NFC with vendored Unicode 16 tables and enforce grapheme/UTF-8/control/markup limits.
- Automated menu navigation, real scene pause/resume, save/ghost/cup/name/mode fixtures pass. Native macOS screenshots were reviewed at 100%/150% UI scale and 4:3; a footer overflow was corrected. These checks do not establish Android menu usability or final art quality.

Current content version is **4**, and protocol version is **5** for lobby/loading/rematch and compact racing control events. The later bot-contract and Summit checkpoints record the content-3/4 changes and archive preservation evidence. Recovery/progress state required by reconciliation is versioned. Older incompatible clients and their records/cups are not silently mixed with this version. Snapshot decoding validates the added lap and distance fields; the eight-car payload remains below 1200 bytes.

## M3 — community lobby checkpoint

- Persistent authoritative direct-guest lobby, eight human seats, four car/eight paint choices, all six track rules, one/two/three laps, bot fill/difficulty and contact selection.
- Ready/unready, 20-second and all-ready five-second timers, manual host Start including a single human, ready reset on selection/rule changes, host transfer, lobby kicks, and private server codes. Direct-guest identities are ephemeral to that worker; official identity/ticket checks are still pending.
- Loading acknowledges actual local collision/world preparation. The worker excludes unloaded humans after 30 seconds, commits the grid, and schedules GO 300 ticks later. Clients cannot join an active race.
- Results carry exact server times/clean laps/distance; clients commit those immutable rows. All-connected Ready for Lobby or the 20-second deadline returns the same room with readiness cleared. Only finished racers can cycle spectator cameras through unfinished cars.
- Bounded reliable fragments handle large Unicode roster/result messages during room transitions; inputs/snapshots remain unfragmented and under 1200 bytes. Clients accept at most 32 partial messages, 16 KiB each, for five seconds; workers reject client fragments.
- Eight independent real ENet clients completed **two races and a rematch**, with all four car definitions, Palm Bay then Citrus Pass, and identical authoritative results on every client. Names were 77 UTF-8 bytes each, exercising fragmentation. See [eight-client evidence](evidence/m3-lobby-eight.json).
- Native graphical Switch/Sunset clients load Redwood Run with six bot opponents. Lobby controls were reviewed at 150% scale; footer controls wrap when necessary. Build 6 installs and runs first-run/name/school-skip/main-menu flows on the Android ARM64 emulator. Wide-screen fill and initial keyboard focus were adjusted from that review and verified on Build 10 in the Android emulator: onboarding fills the wide display and does not open the keyboard automatically.
- A 25-second-away real UDP client is denied re-entry; the remaining client receives its original peer as **Reconnect expired DNF**, with no duplicate identity. See [expiry evidence](evidence/m3-reconnect-expiry.json).
- Finished cars preserve input acknowledgements and stop replaying old human inputs over server autopilot. Terminal visual corrections are reported separately from active-driving/contact populations; the client follows buffered authority after finishing.

## Next

Finish M3: protected client identity, directory menus, remaining settings behavior, same-track retry timing and broader end-to-end mode checks. Regional directory APIs and allocated-worker admission are implemented locally as described below. M4–M6 remain unimplemented. Physical M0/M1/M2 gates stay open while source implementation continues; no physical-mobile acceptance is claimed.


Linux reconnect follow-up: held/neutral server ticks can advance the car without advancing its input acknowledgement. Replaying every unacknowledged frame then duplicated elapsed time, especially when several snapshots arrived together. Reconciliation now uses the snapshot tick and fixed input buffer to bound replay, preserves old frames for redundant transmission, uses monotonic intended ticks, and rejects snapshots until welcome completes. A regression fixture verifies an unchanged-ack pair of snapshots preserves the same predicted endpoint. The local forced-right-lane fault run has moving clear-road p95 0.0183 m; subsequent Linux probes measure 0.0187/0.0191 m. Those probes also exposed stale transport mirrors after forced ENet removal. Forced removal now clears the mirror and queued sends exactly once; a clean local replay measures 0.0211 m p95 with no engine errors. Build 10 subsequently passed the full Linux fault/rematch gates, all exports and native platform startup checks, and was published.


Directory authentication foundation (not yet connected to game menus): Go 1.27 / SQLite guest registration, AES-GCM secret storage, one-use 60-second HMAC challenges, one-hour bearer sessions, five/hour name changes, strict HTTPS/proxy boundaries, bounded JSON, IP rate limits and RSA-2048 admission primitives pass real SQLite/TLS and race-detector tests. Unicode 16 normalization is shared with Godot and grapheme segmentation is pinned. Room allocation, worker admission and Caddy integration are covered by the later checkpoint below. Native client secure storage, client directory menus and public deployment remain pending.

Follow-up contracts to finish before launch: finish the remaining settings/runtime behaviors. The client clock rebase follow-up is covered by the later stall checkpoint. Touch-layout editing is covered below. Remapping and display-dialog lifecycle behavior are covered below. Touch/manual throttle and device ownership are covered below. These are explicit remaining implementation tasks, not established acceptance results.

Directory room API checkpoint: authenticated create/join/code/leave, public compatible-room browsing, eight-seat union reservations, 15-second holds, 60-second signed tickets, stale-worker hiding and bounded readiness are implemented. A separate credential-protected private HTTP handler accepts worker heartbeat/admission consumption and idempotent leave commands. Real SQLite/TLS tests cover concurrent final-seat joins, expiry/replay, private visibility, rate windows, migration and listener isolation; Go race detector and vet pass. A process supervisor, worker integration, native secure storage, client directory menus and deployment remain pending.

Managed-worker checkpoint: the Go service launches an operator-configured, bounded headless process pool outside database transactions and reaps exited children before reusing their ports. Godot `ticket_required` workers verify Go RSA signatures, compatibility, exact expiry and one-use nonces, then confirm reservations through their private credential-protected interface before spawning. Client packets cannot downgrade this mode; direct-guest workers remain separately configured. Official guest UUIDs survive authoritative race results.

Eight independent clients using Go-issued admissions completed Palm Bay and Citrus Pass in the same allocated room, with equal final rows on all clients. A ninth reservation returned 409; live missing/forged/duplicate-ticket probes were denied. See [directory-backed rematch evidence](evidence/m3-directory-eight.json). Cross-language fixture checks cover signed invalid claims, wrong room/worker, exact expiry and packet budget. A real child-process test proves the allocation request ending does not kill its room, pool caps hold, and root cancellation reaps workers.

Pinned Caddy 2.11.7 runs a separate HTTPS/proxy fixture using an isolated test CA without modifying system trust. Real registration/NFC-HMAC auth, nonce replay rejection, direct HTTP denial, private-route isolation and forwarding-header rate-limit boundaries pass; operational logs contain no test credentials. See [HTTPS evidence](evidence/m3-caddy.json). Production logs use fixed structured events, UTC daily rotation, a 100 MiB daily ceiling and seven-day retention. Caddy configuration and local operator CLI are included; public hosting, production certificates, secure client identity adapters and killed-supervisor adoption remain separate work. CI now gates releases on these service/engine integration tests too.

Protocol 4 traffic checkpoint: active-race lobby changes/heartbeats use bounded presence rows, and reconnects use compact IDs/car/paint rows with names resolved from the already received roster. Unknown human names fail reconnect safely; loading exclusions may resolve only shipped bot callsigns. A send guard rejects large reliable events while the worker is racing. Full names/rosters remain available during loading and results, outside active racing. This is a protocol/hash compatibility change; gameplay content remains version 2.

The Godot source suites and Go race-detector suites pass. The first protocol-4 CI run caught a stale protocol-3 JSON schema pin; that schema was corrected before subsequent release checks. An impaired two-client reconnect preserves its slot and exact final results, with p95 moving corrections 0.0199/0.0164 m and zero large racing roster events; see [protocol 4 reconnect evidence](evidence/m3-compact-reconnect.json). The eight-client directory fixture now also disconnects one client for five seconds, restores the same official identity through compact resume, and completes both races with identical rows and zero large racing events. Live missing/forged/reused-ticket probes and Caddy HTTPS boundaries still pass. Ordinary worker stdout reports result counts only; full result-row console output requires an explicit evidence flag.

M3 controls checkpoint: keyboard, gamepad and touch now have a single driving owner; inputs are not combined across devices. Gamepad steering uses the specified radial deadzone/rescale and exponent. A held stick cannot reclaim touch until it moves again, and takeover clears captured touches. Context changes block held button bindings per device until their own release, preventing menu confirmation from becoming a slide after switching devices. Keyboard fallback remains usable independently.

Touch manual throttle, slider/two-button steering, mirrored clusters, size/opacity preferences and two-second controller fade are wired. Mirroring preserves left/right steering semantics. Layouts enforce minimum targets, safe margins and nonoverlap, with the specified compact fallback; screens below 320 logical safe-height points are rejected before starting a race. Online overlay closing keeps touch auto throttle neutral until a fresh steering/throttle touch; focus loss, recovery and inactive/countdown states send neutral driving input. Controller loss pauses offline and gives the specified neutral notice/keyboard fallback online.

All 22 source checks pass, including 120 layout combinations, mixed-device held-confirm regressions and manual touch throttle driving the actual baked-road chassis. Keyboard/controller smoke fixtures now inject real engine input events. The standing-start trial remains valid at 67.223873118 seconds with 1,346 exact-matching ghost samples through the analog input path. Native macOS renders of automatic, manual and mirrored-button touch layouts were reviewed; [manual controls](evidence/m3-touch-manual.png) and [mirrored buttons](evidence/m3-touch-mirrored.png). These diagnostic touch renders do not establish physical-device ergonomics; Android export/emulator and physical-device control checks remain distinct.

M3 display confirmation checkpoint: pending display changes roll back on Revert, close, timeout, screen changes and app teardown. Generation checks prevent old callbacks from touching a newer trial. Keep commits only after a successful save; a failed write restores the prior mode and shows the save error. Restore Display goes through the same trial, restoring only that tab on cancellation. VSync requests apply immediately, persisted desktop modes apply at startup, and returning to Windowed explicitly restores its native border. Numeric setting choices no longer show incidental decimal suffixes; monitor captions are numbered for players.

All 23 source checks pass, including display teardown/navigation, stale callbacks, failed writes and per-tab rollback. Native macOS checks verified the real 15-second timeout (15.208 seconds observed) and borderless/windowed transitions with the window border restored; see [display confirmation](evidence/m3-display-confirm.png). Broader resolution enumeration/application and physical multi-monitor/platform acceptance remain pending.

Build 16 was exported from clean commit 371213c and installed on the Android ARM64 emulator with its stable development signature. The actual settings UI turned touch auto acceleration off, Restart kept the car at 0 mph after GO, and an injected touchscreen hold on GO accelerated it to 33 mph; see [Android manual touch evidence](evidence/m3-android-touch.json). This tests the exported APK and emulator input path, not physical multitouch ergonomics. Build 16 also passed every remote CI gate and published all development packages together.

M3 ghost transaction fix: only a checksum/identity/time-verified ghost matching the committed Trial record can replace the backup. Corrupt or valid-but-uncommitted primary files cannot overwrite that copy. Failed record commits restore the verified prior ghost atomically; a matching backup remains usable even if restoration cannot complete. A regression first reproduced the lost-backup defect, then passed corruption, interrupted primary replacement, failed record commit and successful retry cases. All 24 source checks pass. Native fsync and process-level locking remain M5 work.

M3 remapping checkpoint: Controls opens a keyboard/gamepad editor with two slots per driving/menu action. Capture ignores the opening 0.2 seconds, filters the selected device, waits for actual axis movement, times out after ten seconds, and permits Esc/View/Share or explicit Cancel. Conflicts offer Swap/Replace/Cancel; operations that remove the last keyboard Confirm or Back path are rejected, with unavailable conflict choices disabled. Capture and conflict dialogs hand exclusive focus off before opening the next window. Failed writes retain the old mappings. Native InputMap updates and component persistence are wired; per-device defaults are restorable.

Driving and menu contexts can reuse a binding independently. Defaults include WASD/arrow menu navigation. Driving hints and School captions use the actual saved mappings and selected prompt labels; touch School instructions now describe its controls instead of keyboard keys. School text wraps and omits the unrelated full driving hint list. Dialogs wrap long text and constrain confirmation sizing for smaller viewports.

All 26 source checks pass, including cold-loaded physical input, conflicts, missing/corrupt bindings, essential-path protection, actual capture events, wrong-device input, opening-input suppression, timeouts, cancellation and save failure. Native macOS 150% renders and an actual remap/conflict/School sequence pass; see [remap editor](evidence/m3-bindings-keyboard.png), [conflict choices](evidence/m3-bindings-conflict.png), and [remapped School](evidence/m3-school-remapped.png). Physical controller/platform validation remains open. Builds 17 and 18 subsequently passed the full remote pipeline and published all development packages.


M3 menu repeat checkpoint: keyboard, D-pad and stick navigation now share the specified 350 ms opening delay and 90 ms repeat interval. OS keyboard echo and the drop-down menu's built-in controller repeat cannot add extra steps. A long frame skips missed repeats, screen/focus transitions require release of held directions, and native text editing retains its caret controls. Synthetic navigation does not release a physically held action or enter the driving context.

All 27 source checks pass, including actual engine focus movement, exact timing boundaries, held-context suppression, stick release, drop-down navigation and native text caret behavior. Build 19 also passed the full remote pipeline and published all development packages. Physical-controller menu traversal remains a separate acceptance gate.


M3 result-save checkpoint: completed results now keep a frozen copy of UUID, authoritative order, car state and ghost samples independently of the race scene. Failed writes show Retry Save and require an explicit Continue Without Saving before ordinary offline progression. Cup Next remains unavailable until saving completes; dismissal resumes the last committed Cup checkpoint. A failed new-Cup replacement preserves the prior championship, and stale receipts cannot enter a replacement Cup. Online deadline/lobby transitions retain failed receipts; Main Menu and lobby offer retry or explicit dismissal. Quit warns only while these known unsaved receipts remain. Resetting local records clears pending retries, and Android's main menu omits Quit.

All 28 source checks pass, covering failed Cup replacement/commit, frozen rows after live-state mutation, repeated idempotent saves, pending results after scene replacement and explicit dismissal. Native macOS 150% failure/retry screens were reviewed; see [save failure](evidence/m3-results-save-failure.png) and [evidence boundaries](evidence/m3-results-save.json). Both assertions pass, but the native process reports two GLES texture cleanup errors on shutdown. The same two errors reproduce on pre-change commit 8453062; this remains an open robustness issue. The pre-change harness also exposed unparented result formatter nodes, which are now freed.


M3 touch editor checkpoint: Edit Layout shows a frozen Palm Bay sample with draggable outlines, 8-point grid snapping, minimum targets, safe margins and nonoverlapping Save/Preview gates. Keyboard and controller Confirm/directions/Back provide a mouse-free move path. Layout centers are normalized separately by orientation, phone/tablet class and control variant, keeping automatic/manual, slider/buttons and handedness independent. Cancel discards the draft; failed Save/Restore writes retain the prior settings. Restore Layout affects the active profile only. OS size changes retain the appropriate draft, clamp valid centers and restore defaults with a one-time notice if a saved layout cannot fit.

Preview uses its own 3D/collision world and the actual controller for 30 seconds after GO, then returns to the editor. It never commits records or stats and preserves a paused offline race exactly. The hidden main world stops rendering during editing and is restored afterward. Geometry-changing touch settings, Edit/Restore Layout and Restore Touch are disabled during online races with the specified lobby explanation.

All 30 source checks pass. New tests cover normalized cold reload, 32 independent variants, malformed/overlapping centers, grid-edge snapping, minimum targets, one-time reset notices, real pointer drag/cancel, actual keyboard/controller navigation, failed writes, resize drafts, the full practice interval and paused-race preservation. Native macOS 150% [editor](evidence/m3-touch-editor-phone-150.png) and [driving preview](evidence/m3-touch-editor-preview-150.png) were reviewed; the native editor fixture exits cleanly. Exported Android/editor and physical-device ergonomics remain separate checks. Builds 20 and 21 passed remote checks and published all development packages.


Android export preference fix: the build helper temporarily applies only its SDK/JDK/development-keystore editor keys, then restores those keys and its release-signing environment variables even when export fails. Unrelated editor preferences written during the import are preserved. New temporary configuration files use owner-only permissions and atomic replacement. Three failure/creation/CRLF tests pass, and a real local Android export verified restoration of the previous target preferences. Its local Build 23 metadata correctly records the tooling worktree as dirty; it is packaging evidence, not a clean release claim.


Android 150% follow-up: the exported Build 23 packaging fixture exposed a phone settings body too short to fully display a row beneath the two large tab rows. Phones now use a compact section selector, retaining all eight sections and keyboard/controller focus. Desktop and tablet tab grids remain. The editor, display transaction and complete menu-flow source suites pass; the corrected APK is being checked separately.


Mobile choice follow-up: phone settings and event choices now use a safe-area choice sheet with full-size buttons, a scrollable list and visible Cancel. Keyboard/controller navigation uses the same buttons. Native PopupMenu remains on desktop. The APK check established that a native popup finger drag could select its ending row rather than scroll, so mobile scrolling now captures each finger gesture explicitly, ignores its duplicate mouse event, and selects only a stationary release on the original row. Back closes the sheet before leaving the page; focus loss and teardown release it. No oversized native popup or narrow-scrollbar interaction is required.

All 31 source checks pass, including the actual engine touch drag that reproduced the defect, last-row touch selection, pointer cancellation, keyboard opening/cancel, controller choice, Android Back routing and teardown. Race-time formatting is now a static helper, removing the remaining throwaway HUD nodes used by event/result captions. The clean Build 29 APK subsequently passes actual touchscreen scrolling to the final Data row, selection and Android Back on the Android ARM64 emulator at 150% scale; see [scrolled sheet](evidence/m3-android-choice-scrolled.png), [selected Data page](evidence/m3-android-choice-selected.png) and [package metadata](evidence/m3-android-choice.json). Saved touch positions survive that update. This remains emulator evidence.

The clean Build 26 APK editor flow passes on the Android ARM64 emulator at 150% scale: actual touchscreen drag, 43 mph driving preview, automatic return, Save and retained normalized positions after an update to Build 27. See [Android editor](evidence/m3-android-editor-150.png), [practice](evidence/m3-android-editor-preview.png) and [precise evidence boundaries](evidence/m3-android-editor.json). This does not establish physical-device ergonomics, multitouch or thermal performance. Builds 22 through 28 subsequently passed the full remote pipeline and published development packages.


M3 platform foundation: a small checksum-pinned GDExtension supplies macOS Keychain read/write/delete, Windows user-bound DPAPI protect/unprotect, and optional-runtime Linux Secret Service access. Invalid scopes and oversized values are rejected. Source builds use isolated SCons dependencies; per-platform manifests verify the adapter source and binary hashes. CI builds native adapters on their own runners, merges them before export, tests temporary OS-store entries, and probes adapter loading inside each desktop/server package. Linux remains loadable without a Secret Service runtime and reports storage unavailable.

The actual macOS Keychain round trip, replacement and deletion pass using a new test scope. All 31 source checks also pass with the extension loaded. The Android ARM64 library builds with 16 KiB ELF load alignment, exports into the APK, and reports its backend through the installed emulator package. That Android backend is a loading foundation only: Java KeyStore encryption and protected guest identity integration remain pending. Windows/Linux OS-store and exported package gates await the first remote run for this checkpoint. Build 29 passed the preceding complete pipeline and published its development packages.


The first native CI run compiled all four adapters. Windows then exposed the C++ `.obj` files to Godot’s mesh importer; the source directory now has `.gdignore`. macOS/Linux import encountered the known upstream first-discovery documentation shutdown race (Godot #111048). Extension-enabled import now permits 180 editor frames at 60 fps for deferred documentation generation before shutdown, retaining nonzero/error gates. A fresh-cache native import is checked separately; OS-store test outcomes remain pending.


M3 protected identity checkpoint: first online-use storage creates one UUID and 256-bit secret, keeps the secret outside profile JSON/diagnostics, and persists only a public reference after successful protected storage. Missing/locked/corrupt storage for an existing reference stops loading rather than replacing the identity. A new identity can remain session-only when the OS store is unavailable; ordinary write failures require retry. Failed profile saves and cancelled menu jobs retain the same identity for retry. Registration history is protected with the secret. All OS work runs on one worker, with generation-based cancellation and main-thread profile commits. The directory/menu integration is still pending.

Android now uses non-exportable AndroidKeyStore AES-256/GCM keys, random IVs and scope-bound authenticated data. Ciphertext uses Android AtomicFile under the app no-backup directory; no plaintext fallback or broad storage permission is used. The pinned Java wrapper needs integer-to-boolean conversion, the full inner constructor name and an empty char array for the key-password argument. Its stale last-call exception is not mistaken for a new class-wrap failure. These boundaries were verified through the exported APK.

All 33 source checks pass, including identity/profile transaction failures, cold reload, corrupt/locked/missing handling, record-reset preservation, encrypted-file replacement failure and asynchronous cancellation/retry. Real macOS Keychain write/cold-read/replace/cold-read/delete passes. The local Build 40 APK passes the equivalent Android emulator sequence, non-exportable-key check, tamper rejection and cleanup; see [protected storage evidence](evidence/m3-android-protected-store.json). It is a dirty-worktree packaging fixture, not a clean release or physical/hardware-backing claim. CI now repeats the protected wrapper sequence for each desktop OS. Build 31 passed every remote source/network/service/export/native gate and published all development packages.


A subsequent directory CI run exposed a fixture deadline leak: its deliberate 40 ms no-heartbeat timeout was also left active for the following successful allocations. Those allocations include SQLite and signing work, making the test dependent on runner scheduling. The timeout case retains 40 ms; the later success cases restore a one-second fixture budget. Production readiness remains bounded by its existing ten-second limit.


M3 HTTPS client checkpoint: the engine client registers over verified HTTPS, reloads the protected identity and authenticates by canonical-name HMAC challenge. Bearer sessions remain in memory, and a mutation receiving 401 gets one reauthentication retry with the same UUID. Requests disable redirects, cap decompressed JSON responses at 256 KiB, enforce a ten-second operation deadline and discard cancelled/stale callbacks. Response schemas validate regions, room rows and admissions before menus or ENet consume them. Invalid service JSON fails quietly; authentication/unknown error bodies and session tokens are not emitted to menus or logged. Session-only identities can be explicitly reset even when their unavailable store cannot clean up.

All 34 source checks pass, including malformed JSON/types, strict HTTPS URL boundaries, independent NFC-HMAC bytes, stale completions, timeouts and session clearing. A real Caddy/Go/engine fixture passes region discovery, registration, protected-payload reload, nonce authentication, public allocation/browser visibility, signed-ticket ENet admission, one 401 retry, private visibility/code failure, formatted-code join and leave. Operational logs/profile JSON contain none of its credentials; see [HTTPS client evidence](evidence/m3-directory-client.json). The fixture uses an in-memory store to isolate the transport test; actual platform persistence has its separate native gates. CI now runs this fixture and uploads summaries/logs only. Online menu integration remains pending. The readiness fixture correction also passed the complete Go race suite and 50 focused repetitions.


M3 online menu checkpoint: Play Online exposes Quick Join, Browse Rooms, Create Room, Join Code, Direct Connect and Back. Region Auto selects the lower median of three verified probes; unavailable regions are disabled with an explanation. Official endpoint configuration contains both named launch regions with blank URLs until deployment. Explicit development flags expose Test Region and an optional scoped CA, without changing system trust. The browser refreshes every ten seconds, preserves available/in-race filters, sorts by regional ping/humans/ID and disables unavailable rows. Create/code forms validate names, rules and formatted codes. Quick Join uses humans/age/ID ordering, skips stale failures within its deadline and falls back to creating the specified public defaults. Join offers a ten-second deadline, Retry and Back; cancelled jobs cannot replace a newer screen. Main Menu reflects directory session state.

Departure now flushes ENet before scene disposal and sends an independent best-effort HTTPS leave to release reservations. Workers publish changed leave state promptly and acknowledge removal commands immediately. The directory waits for a pending leave acknowledgement before issuing a new ticket to the same guest, preventing an old command from evicting a new admission. A real UDP fixture repeats immediate client disposal three times and observes each removal before the three-second liveness timeout.

Reset All erases the protected guest before deleting local components, retains local records if protected deletion fails, and restores input defaults/UI settings on success. Record-only reset preserves the identity. A completed-Cup regression also exposed an optional trophy-suppression key inserted as StringName rather than a serializable String; the narrow key fix now prevents a reset trophy from returning after cold load.

All 38 source checks, the complete Go race suite and vet pass. The full HTTPS menu fixture passes regional probes, actual create/browser/code/Quick Join callbacks, signed-ticket lobbies, identity preservation and the Data reset action. Native macOS 150% renders were reviewed: [hub](evidence/m3-online-hub-150.png), [create form](evidence/m3-online-create-150.png), [browser](evidence/m3-online-browser-150.png) and [lobby](evidence/m3-online-lobby-150.png). The fixture exercises the actual macOS Keychain and cleans up its test identity; see [menu evidence](evidence/m3-online-menu.json). CI repeats the full menu fixture, with summaries/logs only in its artifacts. Android online-menu/IME checks remain separate. Build 34 passed all prior remote gates and published development packages.


Android online/IME follow-up: shared menu pages now reserve the actual virtual-keyboard height, hide headings while editing, reveal the focused field and retain at least 48 dp actions. Dismissing the keyboard during a footer press cannot move the target before release. A second emulator check exposed ordinary child widgets consuming scroll gestures; menu scrolling now captures each finger and converts only stationary releases to native widget clicks. Real mouse, keyboard and controller paths remain native. Cancelled/backgrounded fingers cannot activate controls, and choice sheets own their modal gestures.

All 40 source checks pass, including keyboard field/footer geometry, press-time restoration, actual touch drags over buttons, duplicate emulated-mouse suppression, native field/toggle taps and modal ownership. The dirty local Build 40 APK passes these Android 15 ARM64 emulator flows at 150% scale, creates a local ticket-required HTTPS/ENet lobby and cold-authenticates the same protected guest through Quick Join; see [Android online evidence](evidence/m3-android-online.json). Physical-device ergonomics and hosted regions remain unverified. Build 35 passed every remote gate and published all desktop/Android/server development packages.


M3 retry checkpoint: a newly confirmed Quick Race generates a 32-bit event seed outside simulation; Retry retains that seed and roster/grid while creating a fresh result UUID. The accidental five-lap choice is removed, leaving the specified one/two/three. Same-track offline retries retain the collision world. Trial retry restores fresh car/progress/validity/timer/ghost capture and immediately enters the complete 180-tick Countdown, skipping only the initial camera-settle Grid phase; §4.2 now makes that exception explicit. The real scene fixture restores the already-loaded grid in 2.805 ms locally, verifies the same collision world and verifies timing starts with physics after all 180 ticks. This is a desktop source-fixture measurement, not a phone timing acceptance. The Android online fixture's actual Data Reset All also erases its protected guest/profile before cleanup.


M3 world-presentation checkpoint: the 3D world now renders into a separate shared-world viewport, preserving the original simulation/input ownership and native-resolution HUD. Render scale applies to actual pixel dimensions with a 320×180 floor. Retro uses exactly 640×360 and letterboxes outside 16:9; disabling it restores the selected scale. MSAA and anisotropic levels apply to this viewport. Low/High shadow atlas/distance settings differ, and scenery draw distance changes do not cull the road, signs or collision. Menus receive current brightness/graphics preferences when their world is created. Malformed non-dictionary per-platform settings safely restore defaults.

Native Compatibility rendering verifies world textures of 1024×576 at 80%, 640×360 in Retro, and 1024×576 after restoration, while every HUD capture remains 1280×720. The [Retro render](evidence/m3-world-retro.png), [scaled render](evidence/m3-world-scaled.png) and [measured dimensions](evidence/m3-world-presentation.json) were reviewed. Touch layout editing suspends this underlying render, retains its own sample world and restores the main presentation on return. All 42 source checks pass. The dirty Build 41 APK renders both scaled and Retro worlds with the full touch HUD on the Android ARM64 emulator; see [Android rendering evidence](evidence/m3-android-world.json). Exact texture dimensions were measured by the native fixture; physical-device performance is unverified.


M3 loading checkpoint: Quick Race, Trial, Cup and School entry now show a cancellable route postcard, mode/laps, actual current control bindings, local construction progress and a rotating fixed hint. Construction advances through environment, road, collision and bounded scenery batches over separate frames. Cancel frees partial worlds and returns to the originating selection without changing Cup progress; newer loads cannot receive older completions. Same-track Quick/Trial Retry keeps its immediate retained-world path. Track selection now explicitly restores its page/back state after results or cancellation.

Online uses the same local progress work, then shows the loaded-player count while waiting; its ready acknowledgement follows world attachment and a physics frame. Cancelling locked-room loading disconnects with an explanation. All 43 source checks pass, including cancellation across construction boundaries and replacement by a newer track load. The full real HTTPS/menu fixture now readies and starts its allocated worker through staged world loading and collision-ready acknowledgement, in both headless and native-rendered runs. The native 150% [loading screen](evidence/m3-loading-150.png) was reviewed and exits cleanly; [online fixture evidence](evidence/m3-loading-online.json) records the expanded path. Final postcard artwork/input icons remain M4 work.


Client clock-stall correction: Build 38's remote impaired-network gate failed with an input-inactive DNF and acknowledgement stuck at zero after reconnect. The client could keep generating intended input ticks outside the unchanged ±12-tick server window after losing physics backlog, even while its synchronized clock recovered. It now rebases a six-tick discrepancy to leave transport margin, preserves monotonic input sequence, restores current authority and drops stale prediction history. Minimum recent RTT keeps local scheduling stalls out of transit estimates. A receive pass applies only its newest valid snapshot; queued older pongs cannot rewind that authority. Clock restores are measured separately, finishers do not rebase their intentionally stopped inputs, and racing snapshots cannot undo terminal results. No server input acceptance rule changed.

All 43 source checks pass. A real UDP run with 75 ms delay each way, ±30 ms jitter, 3% loss, a deliberate 1.5-second client main-thread stall and a separate five-second disconnect completes both racers with identical authoritative results. Reversed startup exercises the stalled front slot. Moving clear-road p95 is **0.0170/0.0162 m**, contact p95 **0.315/0.324 m**, with 1,069/1,208 clear samples. The stalled client records two bounded clock restores, including a 43.40 m full restore after the stall; that restore is retained rather than averaged into ordinary correction statistics. See [stall evidence](evidence/m3-client-clock-stall.json). CI now repeats this scenario with traces and a cap on rebases. Builds 36, 37 and 39 passed their complete preceding pipelines and published all development packages; the stall fix awaits its own remote run.


Clock-stall contact follow-up: the 340-second impaired UDP fixture also passes under the new receive/clock path: 84 contact episodes, 1,231/1,080 contact samples, contact p95 **0.416/0.449 m**, moving clear-road p95 **0.00854/0.00826 m**, and zero clock rebases. Explicit fixture reset transitions remain separately counted. See [contact evidence](evidence/m3-client-clock-contact.json).

M3 audio-settings foundation: separate Music, Engine, Effects and Announcer buses apply their selected gains/mutes immediately. Master zero is silent; background-audio preference responds to focus changes. Offline pause ducks music 8 dB and exposes movement suspension for M4 engine players; online overlays duck music 4 dB. Cues can duck music/voice 3 dB and restore over 0.3 seconds. Night enables a tuned compressor, with a conservative -1.5 dB sample ceiling on output. Reapplying settings does not duplicate buses/effects.

All 45 source checks pass, including actual DSP samples through the Dummy audio driver: halving Engine gain halves RMS (0.5661 to 0.2826); zero produces zero samples; Night reduces loud-tone RMS to 0.2286 while retaining sound; summed loud sources stay at a measured 0.84141 peak (-1.5 dBFS). See [DSP evidence](evidence/m3-audio-dsp.json). This is a synthetic mixer fixture. Original music/engine/effect/announcer assets, player integration, listening review and the final eight-engine/game-music true-peak test remain M4 work; OS audio-focus/device interruptions remain M5 validation.


M3 Hold Assistance checkpoint: Recover first arms a persistent confirmation, then a second fresh Recover press supplies the same 30 consecutive shared-controller ticks as a manual hold. It does not pause driving or expire into recovery. Back/Pause cancels before ordinary pause navigation; focus loss, inactive play, device takeover, touch cancellation/drag-off and layout resets clear pending assistance. Rapid taps between physics ticks are retained, while held/duplicate device events cannot confirm. The touch recovery icon changes to a check with an explicit caption. Disabling assistance restores manual hold behavior. A settings review also removed the driving camera's residual scenery-distance clip, keeping the road/sign view beyond the independently culled scenery.

All 46 source checks pass. The real baked-world fixture proves recovery occurs on tick 30, preserves trial invalidation and supports keyboard, gamepad and touch cancellation/takeover. The dirty Build 42 APK passes actual emulator taps for arm, recovery and Pause cancellation; see [Android assistance evidence](evidence/m3-android-assist.json). Physical-device ergonomics and final recovery opacity remain separate M4/M5 work.


M3 diagnostics checkpoint: Data Export now creates a bounded local ZIP containing six fixed JSON entries: build, platform capabilities, sanitized settings, the last 60 seconds of numerical performance aggregates, safe event/error locations, and current race rules. Free-form messages, error rationale/backtraces, names, guest references, addresses, room codes, tokens and selected paths never enter the bundle. Logs are bounded and synchronized across engine callback threads. Local destination replacement uses a verified complete archive and sibling temporary file; Android writes through the user-selected Storage Access Framework URI. Cancel and failure remain on the Data page, and internal export caches are removed. Nothing uploads automatically.

All 47 source checks pass, including privacy canaries, malformed fields, ZIP integrity, overwrite failure, size bounds and concurrent logging. The dirty Build 43 APK passes the actual Android 15 ARM64 system save picker, Download write, ZIP readback/CRC checks and Android Back cancellation. Its 2,749-byte export contains 28 seconds of performance buckets and no fixture identity/path/address values; see [Android diagnostics evidence](evidence/m3-android-diagnostics.json), [system picker](evidence/m3-android-diagnostics-picker.png) and [saved result](evidence/m3-android-diagnostics-saved.png). This is emulator evidence; physical devices and other desktop native pickers remain separate acceptance checks. Build 42 passed the complete remote pipeline and published all development packages.


M3 desktop-resolution checkpoint: the native adapter enumerates supported pixel sizes read-only through CoreGraphics/NSScreen, Windows display settings and optional-runtime XRandR. Sizes are deduplicated, bounded and sorted; unavailable enumeration and Wayland offer Native only. Windowed choices apply actual client pixels fitted inside the work area. Borderless/Fullscreen preserve the desktop mode, apply the selected world resolution before render scale and keep native client UI; differing aspect ratios letterbox the world. The Display page explains this behavior. Monitor changes reset resolution to Native inside the same confirmation. Keep/Revert now captures actual window geometry; cancellation/failure restores it, and startup defaults use the current monitor. Invalid saved numeric modes fall back safely.

All 47 source checks pass. The native macOS Compatibility fixture verifies 10 supported sizes, a real 1920×1200 window preview, exact restoration to 1120×630 and its prior position, and a 1920×1200 fullscreen world inside a 3456×2168 native client while the 3456×2234 desktop mode remains unchanged. The OS reserves the notch area. See [dimensions and boundaries](evidence/m3-display-native.json) and [confirmation render](evidence/m3-display-confirmation.png). Multiple-monitor/hotplug acceptance remains open. CI now compiles the Windows/X11 adapters with their platform dependencies and probes the new API inside all native packages; those remote results are pending.


M3 network-quality checkpoint: a five-second delivery window counts every valid decoded 20 Hz snapshot before render coalescing, fills late gaps, ignores duplicates and includes stalled delivery after a 100 ms allowance. Thresholds are the specified 150 ms/3% and 250 ms/8%; RTT uses the current probe mean, and loss waits for one second of evidence. Reconnect/new races reset the baseline. A three-bar shape changes by severity without sounds or automatic pause. Numerical text appears only while the online pause-menu Network Status row has focus and refreshes twice per second. Diagnostics adds numerical delivery loss.

All 48 source checks pass, including exact thresholds, stale traffic, reordering/coalescing, bounded samples and actual UI focus visibility. The 90-second real UDP regression also passes at 75±30 ms each way/3% loss with a 1.5-second client stall and five-second reconnect: identical authoritative finishes, clear-road p95 0.0195/0.0162 m and zero/one clock rebases. The source fixture establishes quality calculations; this wire run establishes no regression to driving/reconnect. Final icon artwork and target-device visual acceptance remain M4/M5.

Build 43 passed every source/network/service/export/native job, then GitHub rejected release creation with HTTP 403 because its target workflow differed from the updated default branch. Publishing now verifies an exact lightweight tag and omits the redundant target-commit parameter. A run superseded by different workflow files keeps its artifacts and explicitly skips tag creation unless its tag already exists; ordinary newer source commits can still release. This avoids granting a broader workflow credential. Build 43 recovery uses its original tested CI packages; no local dirty package is substituted.


M3 accessibility/ghost checkpoint: HUD geometry and text honor UI scale, rival dots retain stable slot numbers in all four selectable palettes, and high contrast makes HUD panels opaque with stronger menu/HUD outlines. A hidden matching Trial ghost is loaded so the pause toggle can reveal it. Global preference initializes entry, the current pause choice survives Retry, Gameplay changes apply to the current race, and a new event reflects the saved preference. The minimap includes a dashed ghost marker. Driving hints cycle two mapped actions every four seconds inside a bounded panel rather than covering the minimap/speed readout at 150%. Replaced race scenes now disconnect viewport/controller callbacks before deferred deletion, fixing a native resize callback into a detached race.

All 49 source checks pass, including matching-ghost Off→On, pause/retry retention, persisted Gameplay updates, palette/contrast/scale application and callback teardown. The native 1920×1080 [150% HUD render](evidence/m3-accessibility-hud-150.png) was reviewed. Final HUD information/artwork, captions with actual announcer assets, nameplates and feedback remain M4 work.

The native accessibility fixture also reproduced the previously recorded two 349,524-byte GLES texture leaks during rapid scene replacement. Sharing the unchanged graybox Sky resource removes both errors; the accessibility render and the updated native failed-save/retry results fixture now exit cleanly. See [cleanup comparison](evidence/m3-sky-cleanup.json). The results harness now waits for staged loading and uses an isolated disposable save folder. This closes the reproduced rapid-world sky cleanup case, not every mobile graphics/lifecycle gate. Builds 43 and 44 passed all test/export/native jobs and were recovered as complete releases from their original verified CI packages after the old publishing command failed; Build 45 passes the full pipeline and publishes automatically with the verified-tag command.


M3 bot-contract checkpoint: passing selects the closest eligible lead deterministically, prefers the side with more paved room, tests both candidate lanes against nearby cars and keeps an absolute ±3 m centerline offset. Blocked sides reduce target speed to the lead speed minus 1 m/s. Stable slot IDs break equal room/lead-distance ties. This corrects roster-order dependence and double application of the current lateral offset. The shared chassis/controller and numeric caps are unchanged. Gameplay content is version 3 with hash `4899e636e87a2e0dbda39be146a526c4f1b3be608fec9411da2a92ca17f5fbc3`; protocol remains 4 and save schema remains 1. Older best times/ghosts stay archived, and incompatible Cups stay intact with Continue disabled.

All 50 source checks pass, including passing clearance/order/ties and cold-load preservation of content-2 records, ghost bytes and Cup bytes. The full real baked-road matrix passes **360 eight-car races, 2,880 finishes, zero recoveries and zero DNFs** across six tracks, three difficulties and 20 seeds. Bots have no random line/reaction variation; seeds rotate four legal autopiloted reference-car choices. All four cars separately satisfy Hard < Medium < Easy on a fixture-only flattened Palm Bay route, without modifying shipped geometry. See [AI evidence and boundaries](evidence/m3-ai-content3.json). This establishes completion and numeric ordering, not human Medium difficulty/feel acceptance. CI now gates gameplay-content changes on the six-shard full matrix plus the single-car ordering; cosmetic commits skip that additional matrix. Build 46 passed the complete preceding pipeline and published all packages automatically.


Pre-art M1 behavior capture is now reproducible with `python3 tools/capture_driving_references.py` (a graphical desktop plus ffmpeg). Nine 1280×720/60 fps clips record full-throttle Comet acceleration, 80 m radius bends at 25/40/50 m/s entry, a clean short slide and grip restoration, wall scrape, rear contact, the actual Pacific Summit jump, and two-pointer touch steering/braking. The developer overlay shows exact input, speed, grounded state and drift phase. Initial transforms, durations, content hash, source revision/dirty flag, camera settings, seed and video checksums are kept in [reference metadata](evidence/m1-driving-references.json). The synthetic flat oval is a reference fixture; the jump uses the shipped Summit bake. Near Chase uses Reduce Motion/base FOV 65 to keep the presentation controlled.

Reviewed frame samples show the slide in Drift, simultaneous touch steering/brake, and Summit airborne. Automated event checks record a clean slide, actual scrape/bump events and one jump/landing with 12 airborne ticks (0.20 s); the 50 m/s bend records a wall impact. Every encoded clip has its exact expected frame count/duration. These are offline-rendered scripted shared-controller references, not human input, physical-device feel or real-time performance evidence. Clips: [acceleration](evidence/m1-acceleration.mp4), [25](evidence/m1-bend_25.mp4)/[40](evidence/m1-bend_40.mp4)/[50 m/s bend](evidence/m1-bend_50.mp4), [slide](evidence/m1-slide.mp4), [scrape](evidence/m1-wall.mp4), [bump](evidence/m1-bump.mp4), [jump](evidence/m1-jump.mp4), [touch brake/corner](evidence/m1-touch.mp4). Human feel, physical phone driving and the explicit-vs-illustrative jump-airtime question remain open.


Lobby reconnect correction: Build 48 lost one client before loading, then seven racers completed an identical first race and the eight-client gate correctly blocked release. The initial transport-loss cause is unproven. A separate real ENet regression reproduced an unconditional identity deletion on unexpected lobby disconnect, making its existing reconnect token unusable. Lobby now reserves that identity/car/paint for 20 seconds, clears Ready, resets the countdown and transfers host administration. Expiry removes the reservation; a valid token can also replace a still-apparently-live old transport during one-way loss. Explicit Leave uses a bounded two-second detached transport owner until the server acknowledges removal, so disposing the UI cannot discard its reliable message.

The real reconnect regression passes identity preservation, host transfer, rejoin, expiry and token handover; Leave delivery passes with immediate disposal and 0/75/150 ms injected send delay. An eight-client run with a deliberate five-second lobby transport loss completes two tracks with all eight finishers and identical results; see [reservation evidence](evidence/m3-lobby-reservation.json). CI now runs both ordinary rematch and lobby-loss rematch, and client fixtures retain bounded numerical connection traces. The M4 working tree passes all 53 source checks; this path-limited network checkpoint adds one source check to the preceding committed suite.


## M4 — original cars checkpoint

Comet, Needle, Switch and Sunset now use four original editable Blender/glTF models rather than the shared car graybox. Each has three explicit LODs, animated steering/spin on four wheels, fixed trim/stripe, all eight paints, grid-number door labels, brake lamps, capped body roll/pitch, landing compression and a road-aligned blob shadow. The Trial ghost uses matching geometry with a 35% alpha tint, no shadow or number labels. Garage, local racers and authoritative rivals use the selected mesh/paint. Startup presents a clear installation error with Retry and Diagnostics if a car/material asset is unavailable.

LOD0 triangle counts are **6,858 / 6,802 / 6,674 / 6,706**, LOD1 **2,310 / 2,326 / 2,270 / 2,282** at 35 m, and LOD2 **458 / 458 / 438 / 458** at 90 m. Every LOD uses five shared-atlas mesh parts (body plus wheels). The original 1024² mipmapped atlas and vertex role masks avoid duplicate extracted textures. Source, regeneration, creator/license, exact dimensions/budgets and checksums ship in the repository. Cosmetic identity `d0fd54bc987590b1756823500008c9108552b7644baaa42b208e010ca9af5468` is separate from the unchanged content-3 gameplay hash and is recorded in build metadata/diagnostics.

All 53 source checks pass. Native macOS Compatibility renders all four models and the ghost, verifies four real Garage selections and an eight-car race, then exits without graphics errors. See [models](evidence/m4-original-cars.png), [ghost](evidence/m4-car-ghost.png), [Garage](evidence/m4-garage-needle.png) and [race](evidence/m4-cars-race.png). The dirty local Build 49 APK renders the four selections and [race](evidence/m4-android-cars-race.png) on the Android 15 ARM64 emulator without shader errors; [validation metadata](evidence/m4-car-validation.json) records the exact parent/dirty build and device boundary. CI now includes a Linux Mesa/Xvfb actual graphics-context gate, since Dummy headless rendering cannot establish shader compilation. Final track/scenery kits, audio, effects, interface polish, recovery opacity and physical-device acceptance remain open.


## M4 — six original course kits checkpoint

All six courses now have their five named original landmarks at the design's original curve-u/lateral anchors. The editable Blender library supplies 30 landmarks, five vegetation models, seven roadside props, three shared neighborhood buildings and two landscape forms. Structural LODs preserve the main shapes while removing lettering, trim and extra segments; landmarks switch at 100/250 m, buildings at 80/180 m, and vegetation at 70/180 m before grouped silhouette cards. Shared original 1024² neighborhood and 512² foliage/prop atlases use mipmaps. Each active asset LOD has one material surface; vegetation/buildings/landscape are batched over bounded course segments.

Six lighting presets, cosmetic terrain chunks, coastal scrolling water, concrete/guardrail profiles, advance direction boards, three start lamps, tunnel panels/lights and Summit jump/landing paint surround the unchanged canonical driving geometry. Camera bounds use a separate layer from vehicle probes/sweeps. Render-only winding correction fixes the old alternating verge/back-face lighting without changing collision input bytes. Scenery distance preserves LOD ceilings and does not remove road guidance. Construction remains cancellable between bounded units. Course selection/loading now use six 512×288 rendered postcards and retain a focused minimap. Frozen pre-art source fixtures preserve M1 video regeneration.

All **54 source checks pass**, including every original-u anchor, imported budgets/UV alpha, structural LODs, immutable collision inputs, camera-only roof collision, countdown lamps and jump markings. Native macOS Compatibility renders the [30 landmark library](evidence/m4-landmarks-library-lod0.png), [distant silhouettes](evidence/m4-landmarks-library-lod2.png), [shared kit](evidence/m4-shared-library-lod0.png) and [24 specified Near Chase references](evidence/m4-course-references.json) at 1920×1080/Medium/no HUD. Six actual rendered eight-car RaceDrive sessions complete with **48 finishers and zero DNFs**; [matrix evidence](evidence/m4-native-course-races.json) records exact development identities and the scripted-input boundary. Native scene/library/reference runs exit without graphics errors.

The dirty local Build 51 APK passes actual touch postcard scrolling/Marina selection and staged entry on the Android 15 ARM64 emulator; [course cards](evidence/m4-android-course-cards.png), [city render](evidence/m4-android-marina-race.png) and [metadata](evidence/m4-scenery-android-validation.json) record that check. A single start-to-ready observation is **1.131 s**; this is not physical-device timing or frame-rate acceptance. Current cosmetic identity is `9130469d39b2bd44633d4d592b795b9898425491143740a833492b15cde97466`; gameplay content remains version 3/hash `4899e636e87a2e0dbda39be146a526c4f1b3be608fec9411da2a92ca17f5fbc3`. CI expands graphics validation to all library silhouettes and 24 course views. Build 50 passed all preceding remote gates and published all 18 release files.

Original audio, feedback/effects, remaining interface details, reference/contrast review on other GPUs, physical driving feel and M5/M6 acceptance remain. This is a course-content checkpoint, not full M4 acceptance.

## M4 — original audio checkpoint

All 48 checked-in Vorbis assets have editable synthesis/composition source and MIT provenance: six 135–150-second course songs at 128–142 BPM, a 90-second menu loop, sixteen engine loops (four profiles × idle/low/high/coast), seventeen effects including the 0.8-second results cue, and the eight fixed original formant/noise announcer lines. The pipeline uses no downloaded recordings, samples, speaker model or external music. The catalog records exact duration, loudness, true peak and checksums. All 26 decoded looping assets pass the boundary-step check; the check caught and corrected one engine's Vorbis startup seam.

Music crossfades between menu and course transports. Four virtual gears use 12/25/40 m/s upshift thresholds, 3 m/s downshift hysteresis, 0.8–1.6 pitch and a 0.10-second shift dip, without writing simulation state. The HUD now displays the presentation gear/tachometer. Own-engine layers stay centered; at most seven actual rivals use spatial players that silence at 120 m. Ghosts never enter the audio roster. Offline pause suspends engine/surface movement; online overlays preserve it. Race events produce bounded-pool effects with wall/landing/pair cooldowns and newest-snapshot deduplication. Countdown, resume GO, lap/finish, results, UI cues and save-confirmed best-time announcements are connected. Wrong-way speech plays once per continuous episode and no more often than ten seconds. Captions remain visible at announcer volume zero.

The actual decoded-stream stress fixture includes all seven music streams, eight four-layer engines, bursts of eight simultaneous impacts plus bump/landing, voice, Night and all-channel mute. Its first capture exposed reconstructed peaks above the former sample ceiling. The final -5 dB sample ceiling measures **-3.41 dBFS true peak** through native macOS Movie Maker final output, with **silent final Master mute**; see [measured evidence](evidence/m4-audio-acceptance.json), [caption render](evidence/m4-audio-caption.png) and [12-second stress-mix preview](evidence/m4-audio-mix-preview.mp3). The fixture deliberately stresses the mixer rather than representing an ordinary race. The existing gain fixture now measures below the limiter and separately measures Night compression. Audio scene fixtures use normal frame pacing and leave time for the mixer to retire stopped streams. CI adds its own actual game-audio capture/true-peak release gate.

Current cosmetic identity is `96a5b19dbb1bb3bf21b4f4cd5efc89b3b7bd139a043d2137e4cf24aab008d7d9`; content-3 handling/protocol identities remain unchanged. Build 51 passed every remote gate and published all 18 desktop/Android/server release files. Human listening/intelligibility, physical phone/tablet/speaker and gamepad vibration acceptance remain open. Feedback particles/skids/recovery opacity and the remaining interface work are the next M4 items.

All **55 source checks pass**, including imported stream contracts, presentation-only gears, silent ghost roster, impact cooldowns, newest-snapshot deduplication, resume GO, independent muted-voice captions and save-confirmed best-time idempotence. The dirty local Build 52 APK passes actual touch entry and shows the new tach/gear HUD in an eight-car race on the Android 15 ARM64 emulator. AudioFlinger reports an active stereo 44.1 kHz game stream, advancing frame count and zero observed underruns; Godot logs show no script errors. [Android image](evidence/m4-android-audio-race.png) and [build/device metadata](evidence/m4-audio-android-validation.json) preserve that limited evidence.

Build 52 passed source, graphics, both eight-client lobby scenarios, all faulted-race checks and six exports, but publication was correctly blocked by two new audio-fixture assumptions: the separate audio job had not created its own `reports` directory, and forced engine shutdown could precede retirement of active audio streams. The audio fixture now creates its output directory; exported-client startup uses the game's explicit stop/drain shutdown instead of `--quit-after`, and the HTTPS menu fixture drains after disposing its scene. The server keeps its independent headless startup path. Local actual game mix capture and explicit client smoke pass; this correction does not relabel the failed remote run.

## M4 — driving feedback and recovery checkpoint

The active race now uses four shared MultiMesh effect batches for original soft tire smoke, sand/grass dust, wall sparks and skid strips. Local/remote smoke caps are 40/15 with 0.6-second lifetime; continuous dust 30/10 with 0.8 seconds; landing dust is capped at 12 per car; wall sparks at 12 per event and eight events/s globally. Reduced halves particle caps and skid sampling density; Off clears effects. Two tire strips share a 200 m total per-car limit, recycle oldest segments and expire after 15 seconds. The first Grid frames submit transparent warm geometry before GO. Effects have no bodies or progress authority, and Trial ghosts remain outside the roster. Offline pause freezes effect evolution and wheel motion; Reduce Motion keeps useful tire smoke.

Recovery now freezes the prior rendered pose during fade-out, moves the camera while the world is fully covered, and fades in over the existing one-second simulation transition. Start/recovery contact grace is visibly 75% opaque; ordinary cars return to their opaque material afterward. The camera sphere now clamps the actual smoothed position against scenery, restores its boom over 0.3 seconds, blends Look Back over 0.12 seconds, and caps collision shake at 0.025 m/0.4 degrees for 0.12 seconds. Reduce Motion removes shake. No recovery timing, collision, progress, route or handling rule changed.

Gamepad feedback sends a sustained weak slip command up to 0.15, bounded collision/landing pulses and explicit cancellation on pause, focus loss, device change and zero setting. It sends no engine vibration or per-frame slip commands. Android's separately disabled-by-default haptics use light UI confirmation and ≤40 ms collision pulses with a 250 ms collision cooldown. Hardware without vibration is omitted. Motor-command fixtures validate bounds/cancellation through an injected adapter; no physical motor feel is claimed.

A presentation event gap was also corrected: the worker now latches existing impact flags across the three simulation ticks between snapshots, encoding a separate view without mutating simulation events. The client retains a bounded 128-entry/500 ms cue queue while coalescing received states, deduplicates snapshot ticks and resets it on race/reconnect boundaries. Audio, effects and haptics have independent cursors, preserving cues from received snapshots without repeating them. Protocol 4 and maximum packet size remain unchanged.

All **58 source checks pass**. Native macOS Compatibility renders ten 1920×1080 [effect/recovery views](evidence/m4-feedback-render.json), including [smoke/skids](evidence/m4-feedback-smoke-skids-full.png), [dust](evidence/m4-feedback-dust-landing-full.png), [sparks](evidence/m4-feedback-wall-sparks.png), Reduced/Off and five recovery phases; all exit cleanly. CI adds these actual shader renders. The [90-second faulted ENet test](evidence/m4-feedback-network.json) passes with 75±30 ms one-way latency, 3% loss, a 1.5-second client stall and a five-second disconnect; the reconnecting client resumes once. Current cosmetic identity is `aa64315035849bfe00cd490fbf4062642f0293b95f61d230cc2cc92583c59dc9`; content-3 gameplay identity is unchanged.

These are scripted native presentation and numerical network/motor-command results. Physical device/controller feel, thermal behavior, remaining HUD/menu/icon work and final M4 reference acceptance remain open.

Build 53 passed every remote gate, including the corrected actual-audio, HTTPS menu and native startup checks, and published all 18 release files at `v0.0.53-dev`.

The dirty local Build 54 APK passes actual touch entry to an eight-car race, Look Back/release and a 700 ms held Recover on the Android 15 ARM64 emulator. The [captured recovery](evidence/m4-android-feedback-recovery.png) shows the world fade and translucent car; logs contain no Godot script errors. [Exact build/device metadata](evidence/m4-feedback-android-validation.json) keeps the emulator and hardware boundaries explicit.


## M4 — original interface assets and selection checkpoint

Sixty original editable SVG icons now cover all 15 actions, eight settings tabs, nine menu modes, three connection states, four car silhouettes, six canonical course outlines, four medal states, three trophy tiers and eight labeled paint swatches. All are MIT, mipmapped and checked against the real route/paint catalogs. Main, Garage, loading, bindings, settings, lobby, touch secondary controls, course cards, Trial results and Cup trophy history use the shared assets with text labels. Garage acceleration/grip bars use the actual car values, not invented ratings. Shoulder buttons wrap all four selections, while mouse drag/right stick rotate the scoped preview.

Course focus now updates a separate description/minimap pane with its own keyboard and touch scrolling. Phone cards reflow from two columns to one at large text; fixed footer actions remain available. A real 150% Android check caught missing touch scrolling in that pane, corrected by using the existing gesture component. Back/car selection also retains the Trial ghost preference. Focused buttons gain the specified small triangle. Frozen DNF cars now suppress stale impact cues, dust, engine/surface output and wheel motion; shared simulation is unchanged.

All **59 source checks pass**. Native macOS Compatibility captures [the complete icon library](evidence/m4-ui-icon-library.png), [Garage](evidence/m4-ui-garage.png), [selected-car gold medal](evidence/m4-ui-trial-gold.png), large-text selection/settings/bindings and Trial/Cup presentation; [metadata](evidence/m4-ui-reference.json) explicitly identifies the synthetic isolated record/trophy fixture. CI adds actual graphics captures. Current cosmetic hash is `9620404cbe7e85958110db58d12d22d3d39884d8751d4462a4037856dd419828`; gameplay content/protocol remain unchanged.

The dirty local Build 55 APK renders actual touch menus on the named Android 15 ARM64 **phone and tablet emulators**. [Phone course selection](evidence/m4-ui-phone-marina.png), [150% independently scrolled description](evidence/m4-ui-phone-details-150.png), [tablet Garage](evidence/m4-ui-tablet-garage.png), [tablet track selection](evidence/m4-ui-tablet-redwood.png) and [exact metadata](evidence/m4-ui-android-validation.json) record this evidence. Physical device ergonomics and performance remain open. Build 54 passed every remote gate and published all 18 desktop/Android/server release files. Race HUD timing/nameplates, remaining interface behavior and final M4 acceptance are next.


## M4 — timing HUD and rival visibility checkpoint

The race HUD now shows authoritative current-lap/best-clean-lap times, a frozen exact finish clock, clean lap rollover and a 1.2-second lap announcement under the specified recovery/wrong-way/finish priority. The north-up minimap has a start stripe and centered route. Trial live delta compares elapsed time against the matching saved ghost at equal course progress; unavailable/invalid runs show no fabricated comparison. The unchanged PRGH v1 transforms supply a bounded lookup, including the exact sub-tick finish. A real shared-controller standing-start Trial finishes in **67.223873118 s**, saves 1,346 samples and cold-loads its matching ghost. Full-route equal-progress self-comparison differs by at most **0.00000589 s** after centimeter quantization. This verifies the timing lookup rather than human driving skill.

At most four nearest rival nameplates appear between 8 and 80 m, with actual scenery/barrier line-of-sight queries bounded to 10 Hz and native-resolution reprojection each frame. Number/name/BOT text accompanies the palette color. Overlapping labels separate vertically and yield to timing panels/captions; ghosts never join this roster. Saved nameplate preferences persist, with fresh defaults off on phones and on for tablets. Touch hides gear/tach, caps the map at 130×90 logical points and keeps the compact speed panel above camera/look-back buttons. Geometry checks cover 100/150% phone/tablet aspects and ensure Pause remains unobstructed. Race cues use one visible prioritized HUD banner when present instead of duplicating an announcer caption. Results hide the race HUD/hints, and the local standings row has a bright border.

All **60 source checks pass**, including real occlusion against an inserted scenery body, nearest-four selection, recorded-progress interpolation, lap/DNF clocks, banner priority and muted-announcer visible cues. Native macOS Compatibility [race HUD](evidence/m4-hud-race-100.png), [large text](evidence/m4-hud-race-150.png), [Trial delta](evidence/m4-hud-trial-delta.png), connection/recovery/hold and [results](evidence/m4-hud-results.png) views are recorded in [reference metadata](evidence/m4-hud-reference.json). These posed reference states do not represent earned medals or a human playtest. CI adds the same actual graphics gate. Content-3/protocol-4/cosmetic identities are unchanged.

Build 55 passed all remote gates and published all 18 desktop/Android/server files. The local development Build 56 Android HUD check is recorded separately below. Final menu behavior, the Summit mixed shoulder surface contract, broad reference/feel review and M5/M6 remain open.

The dirty local Build 56 APK installs in place and renders actual single-car Quick Race driving at 100%/150% on the Android 15 ARM64 Pixel 7 emulator. [Default HUD](evidence/m4-hud-android-100.png), [large text](evidence/m4-hud-android-150.png) and [metadata](evidence/m4-hud-android-validation.json) record the bounded map, omitted gear/tach, accessible Pause and lower-quarter speed panel above the secondary buttons. Observed logs contain no Godot script/parse errors. A physical phone/tablet, full Android race and Android saved-ghost comparison remain separate acceptance gates.


## M4 — menu motion and focus explanations checkpoint

Screen changes now slide horizontally over 0.18 seconds, while same-screen refreshes keep their position and Reduce Motion cuts instantly. The focus triangle transitions over 0.10 seconds. Selection accents use text/icon theme colors instead of modulating the entire control, preserving the bright yellow focus border; selected car names also have a check mark. Paint swatches reflow to two phone/four desktop columns at large text to keep Garage inside its centered safe region.

Focused contextual help appears after 0.5 seconds and dismisses on navigation/scrolling. Disabled online, lobby-start, locked touch-layout and essential-binding controls explain the specific reason immediately on focus and remain nonactivating. Keyboard/gamepad can inspect disabled controls; mouse/touch can focus them. Main help uses available space beside the choices. Dialog help remains within its own window, and overlays do not intercept input. The native [Main focus help](evidence/m4-menu-main-focus-help.png), [selected Garage](evidence/m4-menu-garage-selected.png), [large-text Garage](evidence/m4-menu-garage-150.png), [disabled explanation](evidence/m4-menu-disabled-reason-150.png), slide and instant-cut views are recorded in [metadata](evidence/m4-menu-reference.json).

A regression reproduces and fixes lost very short navigation taps: press/release in the same render frame now emits exactly one initial step for keyboard, gamepad and stick flick, while release cancels held repeats. Changing menu context still cancels queued initial movement. The existing 350/90 ms repeat cadence, OS-echo suppression and text-editing behavior remain covered. All **61 source checks pass**; CI includes native menu references. Build 56 passed all remote gates and published all 18 release files. Physical input devices, screen-reader/human comprehension, instructional demonstration polish and remaining M4/M5/M6 gates remain separate.

The dirty local Build 57 APK passes the actual 150% touch layout check on the Android 15 ARM64 Pixel 7 emulator: [Main contextual help](evidence/m4-menu-android-main-150.png), [dismissal while scrolling](evidence/m4-menu-android-scrolled.png), and [disabled Quick Join explanation](evidence/m4-menu-android-disabled-150.png). The action does not activate; observed logs show no script/parse errors. [Build/device metadata](evidence/m4-menu-android-validation.json) identifies seeded preferences, the owned QA profile and emulator boundary.


## M4 — Driving School instruction checkpoint

All five exercises now have original animated action icons with actual primary key/gamepad bindings beside the caption: accelerate/brake, alternating steering, brake-before-turn, a short held slide followed by release, and a half-second recovery ring. The corner/slide example follows the authored turn direction. Touch confirmation remembers the input device for the next exercise; automatic acceleration is labeled AUTO. Hold Assistance changes the recovery example/caption to two fresh presses with a release between them. Reduce Motion provides a static illustration, and pause freezes it. The guide never writes vehicle input or objective state.

Retry and Skip remain available during each exercise. Retry uses the real staged loading path and resets the same objective/spawn; Skip never invents completion. The recovery success screen waits for the existing full one-second fade, cancels touch captures and then hides the instructional/driving controls. Loading names the exercise rather than showing a racing lap count. Large text updates the teaching panel and its action controls.

All **62 source checks pass**, including real UI clicks through Retry/Skip, remapped Recover, assisted versus held recovery, static/pause behavior, the full recovery-to-success sequence and absence of race-record writes. Native macOS Compatibility renders [acceleration](evidence/m4-school-accelerate.png), [braking into a corner](evidence/m4-school-corner.png), held/released slide, [recovery](evidence/m4-school-recover-hold.png), [large-text assistance](evidence/m4-school-assisted-150.png) and static motion; [metadata](evidence/m4-school-reference.json) identifies the illustrated/frozen-state boundary. CI adds these native views. Gameplay content 3, protocol 4 and cosmetic hash are unchanged. Build 57 passed every remote gate and published all 18 release files. Physical device lesson usability and broader human driving/feel acceptance remain open.

The dirty local Build 58 APK passes the actual Android 15 ARM64 Pixel 7 emulator School flow at 150%: [slide guide](evidence/m4-school-android-slide-150.png), [Recover guide](evidence/m4-school-android-recover-150.png), [in-progress fade](evidence/m4-school-android-recovery-fade.png) and [clean success screen](evidence/m4-school-android-complete.png). Four skipped exercises stay incomplete; only the actually held recovery objective is saved, with zero race records. [Metadata](evidence/m4-school-android-validation.json) and [62 source checks](evidence/m4-school-checks.json) record the bounded validation. No script/parse errors were observed.


## M4 — Summit shoulders and authoritative brake lamps checkpoint

Content 4 corrects Summit shoulders to sand over original base-curve u=[.70,.90), with grass elsewhere and asphalt on the paved road. Sorted, nonoverlapping surface overrides have strict schema/bounds validation. Runtime queries interpolate original coordinates across both the authored seam and rotated starting line. Rendered shoulders split at the same boundaries; all six canonical route bakes remain byte-identical to content 3, with unchanged collision geometry. The real probe fixture checks both shoulders immediately before/after the interval and over the ramp. [Sand shoulder](evidence/m4-summit-sand.png) and the refreshed [24 course views](evidence/m4-course-references.json) capture native Compatibility output.

Protocol 5 carries the actual brake >0.1 / handbrake lamp state in the last existing state flag bit. The complete eight-car snapshot stays **727 bytes**. Remote lamps use authority without receiving another driver's inputs; interpolated discrete state switches at its target tick. [On](evidence/m4-summit-brake-on.png)/[off](evidence/m4-summit-brake-off.png) images round-trip the actual codec before rendering; [metadata](evidence/m4-surface-lamp-reference.json) identifies the posed-state boundary. Physics queries, collision construction and car/track adapters now participate in gameplay hashing. Previous content-3 times, ghost binaries and incompatible cup bytes stay preserved and excluded from current comparisons; content-2 preservation tests remain unchanged.

Build 58's new School source/render gates pass remotely, but its release is blocked by the race-reconnect evidence gate: a one-lap race can finish with fewer than 1,000 active moving correction samples after reconnect. The harness now runs two laps over 160 seconds while retaining the same sample count, 0.5 m clear-road/1.5 m contact p95 limits and complete identical-results requirements. The longer fixture also observes remote brake lamps switching on and off. The failed one-lap run is retained as a failed check, not accepted by reducing its threshold. Full new-version AI/network acceptance and remote release are pending at this checkpoint.

The exact existing jump/ground-snap rules are unchanged; the documented 0.20-second fixture versus illustrative 0.35-second target still requires the requested feel preference. Native/emulator source evidence does not establish physical thermal/input, expert balance, human listening or broader acceptance gates. M5 robustness implementation follows these M4 contracts.

All **63 source checks pass** for content 4/protocol 5; [check report](evidence/m4-content4-checks.json) records the working-tree base. Native [eight-member lobby](evidence/m4-ui-lobby.png), [150% scrollable lobby](evidence/m4-ui-lobby-150.png) and [online hub](evidence/m4-ui-online.png) complete the current UI reference inventory with explicitly synthetic members. The installed local dirty Build 59 release APK boots actual Android Compatibility driving and exits cleanly; [metadata/log](evidence/m4-content4-android-boot.json) retains its emulator-only boundary.

The full content-4 AI matrix passes **360 eight-car field races / 2,880 finishers / zero DNFs / zero recoveries** across six tracks, three difficulties and 20 seed/car rotations. The separate four-car flat-reference ordering remains Hard < Medium < Easy; [matrix summary](evidence/m4-ai-content4.json) retains the deterministic-bot/human-feel boundary.

The isolated **two-lap 160-second faulted ENet run passes** with 75±30 ms one-way delay, 3% loss, 1.5-second stall and five-second reconnect. Both clients receive identical two-finisher results; moving sample counts are 2271/2377 and both authoritative lamp states are observed. Clear-road p95 is 0.0165/0.0155 m; terminal/autopilot corrections stay separate in the [full network evidence](evidence/m4-content4-network.json). Current gameplay hash is `538d6c1dec5d175634a818fb0b127c51c85439ffe29ad919aa653e54214d9170`; cosmetic identity remains unchanged. M4 source/assets and the current reference inventory are complete; human feel/listening/balance and physical-device acceptance remain open as M5 source robustness work begins.


## M5 — durable saves and profile ownership checkpoint

The existing native extension now provides lifetime profile leases and file/directory synchronization. Same-process stores share ownership; another process reads committed components but cannot write/delete them or write ghosts, and receives a one-time read-only notice. The OS releases the lease after a killed owner. JSON and ghost temporaries/backups synchronize before replacement; POSIX directory entries synchronize through the profile's parent. Windows uses file flushes/write-through replacement with an explicit directory-durability limitation. The schema-1 JSON and PRGH formats are unchanged. [Storage contract and OS references](SAVE_DURABILITY.md) describe boundaries.

A durable deletion marker prevents an interrupted Cup/reset deletion from resurrecting a backup. Writers recheck future envelopes even after an earlier load, and preserve those bytes. Corruption remains component-local. Native relative paths reject parent traversal, symlink escapes and reserved lock names, including case aliases. Exported packages require the native adapter for saves; source-only fixtures identify their fallback.

All **65 source checks pass**, including compilation of all **99 shipped scripts**, prior corruption/ghost/stat-journal fixtures and the new [barrier/deletion checks](evidence/m5-save-checks.json). The optional exported probe initially exposed a type-inference error; explicit typing and the compile-all gate fix that before publication. Native macOS [independent-process evidence](evidence/m5-save-native-process.json) passes second-writer read-only behavior, owner kill/reacquisition, five interrupted write stages and two killed deletion stages on a Unicode temp path. CI adds these actual native checks on Linux/Windows/macOS. A physical power-cut guarantee is not claimed.

Build 59's ordinary two-lap reconnect gate passes remotely. Its expiry gate rejects the newly added lamp transition assertion because an expiring rival may freeze before ever braking; the contact fixture explicitly uses constant throttle too. The lamp assertion now applies only to ordinary complete races. Existing expiry/contacts sample, correction, identity and results requirements are unchanged. The [two-lap 25-second-expiry rerun](evidence/m5-expiry-network.json) passes: the expired human has one DNF identity, cannot rejoin, and the remaining client receives both authoritative rows with more than 1,000 moving samples. Build 59 remains blocked; no successful release is claimed for that run.

Gameplay content 4/protocol 5 and the asset identity are unchanged. Android exported native checks, cross-platform remote CI/release, cold offline lifecycle resume, OS focus/connectivity, adaptive quality, memory pressure and physical thermal/device/human acceptance remain separate gates. Work continues in M5.

The final dirty local Build 60 release APK passes all **11 cold-process Android save steps** on the owned Android 15 ARM64 Pixel 7 emulator: write/read/replace, failed replacement, held native lease, independent external lock rejection, lock release after force-stop, interrupted deletion, empty cold reload and UUID-only cleanup. [APK/build/device evidence](evidence/m5-save-android-process.json) records the exact artifact and emulator boundary. This validates actual exported native storage behavior; physical storage/power-loss/thermal checks remain open.

The final ownership guard also blocks every protected-identity operation in a read-only second process; the existing asynchronous cancel/retry test covers this before any worker or credential write starts. The final 65-check run and repeated exported 11-step Android probe pass after that guard. Native macOS/Android manifests match the final source. Other-OS native behavior awaits CI.

Build 60 passes its remote source/render/audio, directory, reconnect/expiry and contact gates, but native Linux storage acceptance fails on its clean checkout before exercising files: `SaveStore` is not registered because the new harness runs before any Godot import. The harness now performs the same headless editor import as the existing native identity harness, then runs the process probes. This is a bootstrap repair; the prior local native/Android behavior is not reclassified as a remote pass. Release 60 remains blocked.

A fresh archived checkout of the committed storage checkpoint, with no `.godot` cache and only its built macOS adapter copied in, now passes import and every native process probe with the patched harness. [Clean-checkout evidence](evidence/m5-native-clean-checkout.json) identifies the base commit and exact patch; cross-platform CI remains the final check.


## M5 — offline mobile lifecycle checkpoint

Mobile backgrounding now atomically saves the full offline race after freezing simulation and clearing inputs. The format preserves controller doubles/vector values exactly, every car's progress, timer/phase, seed/roster, bot plans and School objective state. Cold launch offers Resume Offline Race or Discard before onboarding; Resume goes through real staged loading and the frozen three-second safety countdown. The original race UUID and Cup event survive. A cold interrupted Trial starts fresh; ordinary warm Trial resume is marked invalid for records. Unsupported content/newer payloads stay preserved until explicit Discard. Result journals and successful School profile saves govern checkpoint removal. [Recovery contract](OFFLINE_RESUME.md) records failure and preservation rules.

All **67 source checks pass**, including **101 shipped scripts**, exact eight-car/bot continuation through 120 ticks with **0.000000000 m** position difference, Cup event identity/single commit, malformed/unsupported payloads, actual UI/loader actions, touch cancellation, duplicate notifications and exact 180-tick freeze. [Check evidence](evidence/m5-checkpoint-checks.json) records the working-tree base. Native Compatibility [large-text Resume](evidence/m4-ui-saved-race-150.png) and [unsupported version](evidence/m4-ui-saved-race-incompatible-150.png) fit without the empty footer; [metadata](evidence/m5-checkpoint-reference.json) distinguishes scripted references from OS lifecycle.

The dirty local release Build 62 passes real Home → checkpoint → force-stop → cold touch Resume on the Android 15 ARM64 Pixel 7 emulator. Its saved timer remains exactly **348 ticks / 5.800 seconds** and packed position/UUID remain identical while the [rendered countdown](evidence/m5-checkpoint-android-countdown.png) freezes the world. After a second cold resume/countdown, the same race advances to **492 ticks**, with no observed script/parse errors. [Exact APK/device metadata](evidence/m5-checkpoint-android.json) and [cold prompt](evidence/m5-checkpoint-android-cold-prompt.png) record the evidence and the minor final UI-only differences. The owned QA profile is archived; unrelated profiles are preserved.

Build 61's bootstrap repair is queued remotely at this checkpoint; releases 58–60 remain blocked. The latest confirmed publication remains Build 57. Gameplay content 4/protocol 5 and cosmetic identity are unchanged. Online OS background/Away, audio focus/connectivity, keep-awake, adaptive quality, memory pressure, shader warming and physical-device acceptance remain M5 work.


## M5 — online mobile suspension checkpoint

Mobile focus/pause now sends best-effort Away, flushes the existing ENet transport and closes it. Local prediction, queued controls, heartbeats and retry processing stop while suspended. The server immediately takes over with its existing bot and preserves the same 20-second reservation; a lost Away still has the existing liveness fallback. Foreground reconnect reuses the token, identity and race, restores authority and leaves the overlay open until explicit Resume. Online Resume grants no offline countdown, and touch automatic acceleration still requires a fresh steering/throttle touch. Online state never enters `suspended_race.json`.

If local preparation finishes while disconnected during Loading, readiness now latches and is acknowledged on reconnect. This prevents a fully prepared client waiting forever for a loading event it already received. Mobile background audio always mutes, even when the desktop background-audio preference is enabled; suspended online race engines/surfaces stop movement playback.

All **68 source checks pass**; [check report](evidence/m5-online-checks.json) records the working-tree base. The real local ENet lifecycle fixture exercises Loading interruption/re-acknowledgement, immediate authority takeover, unchanged local prediction/sequence/bytes during suspension, full same-identity race resume and an actual **20.1-second** suspended expiry. Authority marks one DNF and the client shows connection loss without manufacturing stats/results. The existing fresh-touch ownership and desktop audio preference tests still pass.

The dirty local Build 63 release APK passes actual Android Home and return against a local worker/native companion. The Android PID survives both transitions; [the reconnected Pause overlay](evidence/m5-online-android-pause.png) waits for a real touch Resume, [gameplay returns with neutral controls](evidence/m5-online-android-resumed.png), and a second **21-second** Home suspension reaches [the expiry screen](evidence/m5-online-android-expired.png). Worker logs record the original Android slot dropping within one tick of its last received input both times. [Exact APK/device metadata](evidence/m5-online-android.json) distinguishes the APK check from the subsequent source Loading fix. The QA profile is archived and temporary worker/companion processes are stopped. This is emulator evidence, not physical cellular/call/thermal acceptance.

Build 61 subsequently passed remote CI and published all **18** desktop/Android/server release files as [v0.0.61-dev](https://github.com/maccam912/racinggame/releases/tag/v0.0.61-dev); blocked releases 58–60 remain recorded. OS audio-focus callbacks, metered-data notice/connectivity, keep-awake, adaptive quality, memory pressure and shader warming remain M5 work.


## M5 — adaptive presentation and foreground resource policy checkpoint

Foreground gameplay/loading and active touch practice keep the display awake; Pause, results, menus and background release it. The OS memory warning drops menu previews and reusable cosmetic cache references while retaining live resources, active loading, collision, state and mandatory catalogs. Render review caught canvas icons losing their resources after cache clearing; the bounded shared icon cache now stays owned, and the [post-pressure view](evidence/m5-runtime-memory-pressure.png) retains every control.

Mobile adaptive resolution now follows the selected 30/60 FPS budget with two-second overload / ten-second headroom windows, ten-point steps, a 60% floor and the selected ceiling; an explicitly selected 50% remains respected. Only the world SubViewport changes. Native HUD, AA/effects, saved preferences and 60 Hz simulation remain fixed. Pauses, menus, background, Retro and OS gaps break the measurement window. Eligible gameplay records actual CPU/render timing with the documented GLES GPU-query fallback. [Runtime contract](MOBILE_RUNTIME.md) explains measurements and limits. Numeric effective scale/dimensions, timing, changes, keep-awake and memory count join the existing diagnostics archive without personal data.

All **69 source checks pass**, including **103 shipped scripts**, both frame caps/hysteresis, unchanged HUD/AA/settings, preview reconstruction and active physics-space/state retention; [check evidence](evidence/m5-runtime-checks.json) records the base. Final targeted runtime/world/diagnostics privacy checks also pass. Native Compatibility renders [selected 80%](evidence/m5-runtime-selected-80.png), [adaptive 60%](evidence/m5-runtime-adaptive-60.png), injected memory pressure and restored 80%; [metadata](evidence/m5-runtime-reference.json) clearly separates synthetic load/headroom from live timing instrumentation. CI adds this native rendering gate.

Dirty local release Build 64 passes actual Android emulator Window flag checks: `KEEP_SCREEN_ON` is present during [gameplay](evidence/m5-runtime-android-playing.png) and absent on [Pause](evidence/m5-runtime-android-paused.png), Home, cold saved-race prompt and [Main Menu](evidence/m5-runtime-android-menu.png). [Artifact/device metadata](evidence/m5-runtime-android.json) identifies the exact APK and final source-only differences. Its owned QA profile is archived. No physical display/thermal or actual Android memory exhaustion is claimed.

Builds 62 and 63 pass remote CI; Build 63 publishes all **18** packages/manifests/checksums as [v0.0.63-dev](https://github.com/maccam912/racinggame/releases/tag/v0.0.63-dev). Gameplay content 4/protocol 5 and cosmetic identity remain unchanged. Audio-focus/call integration, cellular notice/connectivity, loading shader warming, broader faults/soak and physical-device acceptance remain M5 work.

Storage size follow-up: saving now enforces the existing **16 MiB UTF-8 envelope** read limit before touching any files. A boundary-sized envelope writes and cold-loads; one extra byte and an 18 MiB multibyte string are rejected with primary/backup/pending bytes preserved. This prevents a successful write creating a save that the next launch cannot read. The actual native independent-process barrier/kill matrix and all five affected Cup/ghost/stat/archive/UI suites pass again; [targeted evidence](evidence/m5-save-size-checks.json) records the base. No automatic record pruning, schema, gameplay or asset changes are introduced.


## M5 — Android audio focus and default-network recovery checkpoint

An original small Godot v2 Android bridge now follows native audio-focus callbacks and reads the default network handle/kind. Offline interruption cancels touches, pauses and checkpoints; online uses Away/reconnect. Music pauses in place, interrupted one-shot cues are discarded, and audio gain leaves driving paused until explicit Resume. Permanent loss/denial offers reachable Retry Audio; a background window cannot regain controls from an audio callback. New races entered while interrupted start paused. An established connection changing routes reconnects its existing token/slot/race without extending its reservation deadline. [Bridge/build/runtime contract](ANDROID_SERVICES.md) records the rules and OS references.

A first online start on cellular offers Continue/Cancel before any directory/ENet operation. Consent survives cold profile reload, with legacy profiles still valid; failed preference saving retains consent for that process and queues the ordinary notice. Direct Connect no longer opens the IME automatically on mobile, and confirmation releases text focus/hides the keyboard. Modal replacement hides its predecessor before deferred deletion. Android Back cancels the modal before page navigation, and themed mobile dialogs provide borderless, at-least-48-point actions. APK inspection still finds only **internet, network-state and vibration** permissions.

All **70 source checks pass**, including **104 shipped scripts**, actual ENet route replacement, focus/window/input/checkpoint/music rules, explicit retry, cellular cancellation/failed-save/cold consent and legacy validation; [full check report](evidence/m5-services-checks.json) records its base. Seven [final targeted source checks](evidence/m5-services-final-source.json) cover modal/IME/Back/target size, keyboard/menu, identity reset, diagnostics privacy, offline resume and shipped-script compilation after refinements. A checksum-pinned Godot library/JDK 17 compile produces a [repeatable AAR](evidence/m5-services-reproducible.json). APK and AAB [manifest/DEX gates](evidence/m5-services-package-structure.json) confirm inclusion; the exporter now requires them before success. The dirty local macOS universal package passes [actual native startup](evidence/m5-services-native-macos.json). The AAB's development signature verifies; production signing remains separate.

The Android 15 ARM64 emulator delivers a real telephony `LOSS_TRANSIENT` callback to the installed bridge. The release APK checkpoints, retains its PID, returns to Pause and freezes the same UUID/position at exactly **80 ticks / 1.333 seconds** through [Resume's countdown](evidence/m5-services-android-call-countdown-final.png). Actual touch Cancel starts no connection; Continue writes consent, and cold launch remembers it. [Call/consent metadata](evidence/m5-services-android-call-consent.json) identifies the exact APK before the final modal styling/Back refinement. Separate [final-APK modal evidence](evidence/m5-services-modal-android-final.json) and [accessible dialog](evidence/m5-services-android-cellular-accessible-final.png) / [Back cancellation](evidence/m5-services-android-cellular-back-fixed.png) verify the final interaction.

Actual emulator **Wi-Fi → cellular → Wi-Fi** switching also passes against an independent real ENet authority/native companion: three transports retain one Android identity, slot **1**, the same race UUID and exactly two humans. [Handover summary](evidence/m5-services-android-handover.json), [authority events](evidence/m5-services-handover-authority.json) and [returned gameplay](evidence/m5-services-android-handover.png) record the bounded run. All owned QA profiles are archived, temporary workers are stopped, and original emulator network settings are restored. No real telephone call, physical radio/carrier handover, hardware listening or thermal acceptance is claimed.

Build 65 passes remote CI and publishes all **18** desktop/Android/server files as [v0.0.65-dev](https://github.com/maccam912/racinggame/releases/tag/v0.0.65-dev); the new bridge awaits its own remote release. Gameplay content 4/protocol 5 and cosmetic identity are unchanged. Loading shader warming, broader adversarial/soak checks and physical phone/tablet acceptance remain M5 work before M6 publisher/hosting gates.


## M5 — graphics preparation before Grid checkpoint

Loading now reserves its final progress unit for actual GPU submissions in a private 256×256 world. It draws the selected course's real material/mesh formats, all four cars and LODs, normal/fading/ghost surfaces, slot glyphs, shadows and instanced effects. Two consecutive foreground frames and GPU readback with visible draw calls precede completion. The detached course never registers collision in the warm-up world; retained model/material references survive temporary-scene disposal. Background waits, failure offers Retry/Cancel, and stale/cancelled work cannot start a race or send Loaded. [Graphics-loading contract](SHADER_LOADING.md) describes ownership and hardware boundaries.

All **71 source checks pass**, including **105 shipped scripts**, all six course inventories/all eight shaders, instancing, four retained model resources, no warm-up physics, cancellation and explicit headless evidence boundaries; [check report](evidence/m5-shader-checks.json) records the base. Actual native Compatibility renders all six courses with disabled/2×/4× MSAA and **38–46 submissions / 89–101 draw calls**. Grid remains at tick zero, and an actual ENet authority receives no Loaded while graphics are held. Failure injection, the real Retry button, Cancel and background waiting pass. [Native metadata](evidence/m5-shader-warmup.json), [Loading](evidence/m5-shader-loading.png), [material inventory](evidence/m5-shader-material-grid.png) and [Retry](evidence/m5-shader-retry.png) record the checks. Native loads in this fixture are under two seconds; this is not a universal cold-cache or no-stutter guarantee.

The dirty local Build 67 release APK passes all **six** actual course loads on the Android 15 ARM64 Pixel 7 emulator against an independent local ENet authority/native companion. Each reports two drawn frames and **89–101 actual draw calls before Driving Ready**; authority confirms the two humans and a live race. [Exact APK/build and numeric evidence](evidence/m5-shader-android.json), [Palm Bay grid](evidence/m5-shader-android-palm_bay.png), [Marina grid](evidence/m5-shader-android-marina_lights.png) and [Summit grid](evidence/m5-shader-android-pacific_summit.png) identify the boundaries. All six owned profiles are archived and temporary workers stopped; emulator networking is unchanged. This is not physical GPU/thermal acceptance.

Build 66 passes remote CI and publishes all **18** desktop/Android/server files as [v0.0.66-dev](https://github.com/maccam912/racinggame/releases/tag/v0.0.66-dev). Build 64's macOS startup job was cancelled and publication skipped; subsequent Builds 65/66 passed. The graphics checkpoint's remote render/release gate is pending. Gameplay content 4/protocol 5 and cosmetic identity remain unchanged. Broader adversarial/soak and physical phone/tablet checks remain M5 gates; M6 publisher/hosting gates remain open.


## M5 — initial connection ownership checkpoint

Repeated Connect/Submit now keeps a single admission attempt; pending Connect is disabled and Back stays available. Keyboard/Android Back sends the same explicit Leave as the visible button, including when the worker has admitted a guest but Welcome has not reached the UI. Initial admission has a fixed **ten-second** deadline independent of ENet connection/ping traffic, with focused Retry and retained fields afterward. Background before Welcome cancels rather than creating a second guest; established reservations retain their existing reconnect behavior. Address/code validation precedes cellular consent. Every client callback verifies current ownership, terminal errors end their packet batch, and official-directory cancellation sends Leave before cleanup. [Connection lifecycle contract](CONNECTION_LIFECYCLE.md) records the rules.

All **72 source checks pass**; [full report](evidence/m5-direct-checks.json) records the base. The new real-ENet fixture reproduces the original reentry failure, then verifies one transport/seat, actual Back and background cancellation before Welcome, a real ten-second silent handshake, explicit Retry, focus and stale callback/error-batch rejection. A fixture-only unparented transport cleanup error was corrected before the final full run. The actual [HTTPS directory menu integration](evidence/m5-direct-directory.json) passes again, and the native all-six-course graphics/ENet readiness fixture remains green.

The dirty local Build 68 release APK passes actual Android Back and ten-second timeout against a separate authority that deliberately withholds Welcome but still answers pings and Leave. The authority records exactly one seat, then removes it in both cases; the client starts no race. [Exact APK/build and steps](evidence/m5-direct-android.json), [pending form](evidence/m5-direct-android-pending.png), [Back return](evidence/m5-direct-android-back.png) and [Retry form](evidence/m5-direct-android-timeout.png) identify emulator/command-line-fixture boundaries. Both owned QA profiles are archived and temporary workers stopped. Physical-device and carrier behavior are unverified.

Build 67's graphics checkpoint remains in remote CI at this checkpoint. Current gameplay content 4/protocol 5, save schema and cosmetic identity are unchanged. M5 packet-fault/soak and physical-device gates remain; publisher signing, public regions and M6 release acceptance remain open.


## M5 — malformed traffic and receive-budget checkpoint

Application ENet reads now stop after **256 raw packets per pass**, including discards; remaining packets wait for the next pass. Oversized payloads/client fragments and retired-peer packets are discarded before authority processing. Control text rejects invalid UTF-8 and raw/escaped NUL before Godot can replace characters or log them. Literal backslashes and multilingual/emoji names remain valid. Unicode replacement diagnostics now fail the engine runner. Client events enforce channel roles and refresh liveness only after validation; workers refresh it only for valid input in the existing tick window or a valid ping. Repeated Loaded is idempotent. [Packet contract](PACKET_FAULTS.md) distinguishes the application budget from ENet/socket and public-host protection.

All **73 source checks pass**, including all **105 shipped scripts**; [full report](evidence/m5-packet-checks.json) records the base. The real ENet adversarial fixture checks **1,034 valid UTF-8 samples / 93 invalid encodings**, raw/escaped NUL, and a queued **512-packet** burst: **171** oversized discarded, **341** legal messages delivered once over two bounded passes. A real eight-car worker removes a sustained offender after about **5.1 seconds** while the healthy driver continues. Reconnecting that same owned reservation and sending malformed-only traffic below the rate cap triggers the unchanged **three-second** liveness takeover. Invalid/wrong-channel client data cannot extend its clock; fabricated finishes and stale post-drop packets have no effect. [Numeric fault evidence](evidence/m5-packet-faults.json) records the bounded local-only scope.

The separate **160-second two-lap** real-UDP run also passes with **75±30 ms one-way delay, 3% loss, 1.5-second client stall and five-second reconnect**. Both clients receive identical two-finisher standings, and the original slot returns. Moving clear-road p95 is **0.0161 / 0.0145 m** over **2,131 / 2,255 samples**; [full network report](evidence/m5-packet-network.json) retains maxima, contact, terminal and restoration populations separately. This does not establish the ten-race/eight-client acceptance row or physical cellular behavior.

Builds **67 and 68** pass remote CI and each publishes all **18** desktop/Android/server files: [graphics checkpoint](https://github.com/maccam912/racinggame/releases/tag/v0.0.67-dev), [connection checkpoint](https://github.com/maccam912/racinggame/releases/tag/v0.0.68-dev). This packet checkpoint awaits its own remote release and current-APK cross-play follow-up. Gameplay content 4/protocol 5, save schema and cosmetic identity are unchanged. M5 broader soak/physical-device gates and M6 publisher/hosting gates remain open.


## M5 — eight-player Android cross-play and portable names checkpoint

The actual eight-member emulator/native fixture found Android counting a family-emoji name as 23 code points while desktop counted its five graphemes. Android rejected the legal roster/Loading and never acknowledged readiness. Names now use a bundled, platform-independent Unicode 16 extended-grapheme implementation, including Indic linkers and emoji sequences. NFC, the 96-byte cap and existing exclusions remain intact. Both game and directory check all **1,093 official boundary vectors**. [Name contract and reproduction](UNICODE_NAMES.md) documents the pinned generation inputs and bounded numeric diagnostics.

All **75 source checks pass**, including **106 shipped scripts**, and the complete directory suite passes with the Go race detector: [source evidence](evidence/m5-unicode-checks.json), [directory evidence](evidence/m5-unicode-go.json). The 512-packet fault fixture now stages reliable traffic in acknowledged four-packet batches before application reads, avoiding kernel-queue-dependent packet loss while retaining the exact 171-discard/341-delivery/two-pass assertions. [Failed Android attempts](evidence/m5-unicode-failures.json) remain explicitly failed, including the collector failure after a successful first race when Android truncated a long Unicode console line. Short canonical standings digests replace that client console payload; complete owned rows remain in authority/native files.

The dirty local Build 70 release APK and **seven native clients** now complete a normal-timer race and rematch on Palm Bay/Citrus Pass. All **16 finishes** have no DNF or bots, use all four car types and retain the same eight identities. Full authority/native standings match Android's digest of the complete parsed rows for both races; Android prepares graphics twice and commits exactly **two** results. [Exact APK/build/device and comparison evidence](evidence/m5-unicode-mixed.json), [actual Android grid](evidence/m5-unicode-android-grid.png) and [results](evidence/m5-unicode-android-results.png) record the run. The test's unique profile is archived and all temporary processes stopped. This is automated emulator/autodrive evidence; physical touch, thermal and the ten-race impaired-network matrix remain open. Emoji glyph presentation remains a separate rendering concern visible in these screenshots.

Build 69 passes remote CI and publishes all **18** desktop/Android/server files as [v0.0.69-dev](https://github.com/maccam912/racinggame/releases/tag/v0.0.69-dev); this checkpoint awaits its own remote build. Gameplay content 4/protocol 5/save schema 1 are unchanged. Unicode attribution updates the cosmetic digest to `c0bc31a05f0ddb222f8684441fa503a87747bed7351827cda9c3d8e7f29bde3e`. Remaining M5 server-capacity/soak and physical-device gates precede M6 publisher/hosting acceptance.


## M5 — worker measurements and capacity policy checkpoint

The authority now times its complete physics callback in a fixed-size 30-second history. Private heartbeats report nearest-rank tick p95/p99/maximum, deadline misses, active cars and **current native process RSS**. Native reads use Mach on macOS, process working set on Windows and accurate Linux `smaps` rollup/mappings; unavailable values stay explicit zero. Heartbeat serialization, native RSS reads and structured log output occur outside the measured physics callback. Managed readiness waits for 60 ticks while retaining the existing ten-second startup limit.

The shipped directory command refuses **additional room creation** when any existing worker lacks fresh measurements, reaches **8 ms p95**, reaches **256 MB** RSS or raises the full-window deadline alert. The static process cap remains. Existing joins/reconnects/races continue under their existing rules. Authenticated committed heartbeats feed a bounded cache and numeric-only operator log; **5%** of ticks strictly above **16.67 ms** over a complete **30-second** window raises one alert edge, with recovery. [Performance contract](SERVER_PERFORMANCE.md) describes observation limits and the 20% margin below 10 ms.

All **76 source checks pass**, including **107 shipped scripts**: [full report](evidence/m5-performance-checks.json). The complete Go race-detector suite passes, including exact thresholds, stale/unknown/unauthorized measurements, capacity refusal without leaked allocations, preserved existing-room joins, release cleanup, bounded cache, alert/recovery edges and schema bounds. Actual universal macOS RSS rises by **33,603,584 bytes** after touching 32 MiB; the native probe now joins the cross-platform adapter CI. The complete actual HTTPS menu/worker flow passes with fresh private numeric reports and guarded allocation: [integration summary](evidence/m5-performance-directory.json), [native/Go/heartbeat evidence](evidence/m5-performance-policy.json). Cross-platform native probes await this checkpoint's CI.

A separate eight-client, ten-race real-UDP impairment run is active at this checkpoint, with a minimum 16-minute lifetime for five-to-fifteen-minute RSS comparison. Its eventual result will be recorded separately. No documented two-vCPU x86-64 host performance, physical Android thermal/input or public regional capacity acceptance is claimed. Gameplay content 4/protocol 5/save schema 1 and cosmetic identity are unchanged.


## M5 — exported name rendering and editing checkpoint

Android's tested system emoji font uses unsupported COLR/CPAL tables: accepted family, race-flag and skin-tone sequences were invisible even with explicit OS font loading. Both original Barlow faces now have a shared, bundled **Noto Color Emoji v2.051 CBDT/CBLC fallback**, pinned to exact upstream bytes with its Open Font License and in-game credit. All UI/HUD/caption/3D text references use those resources. Exports include the pinned engine's **4,797,072-byte ICU support data** for correct text boundaries. A shared text-field factory enables complete-composite Backspace deletion; ICU alone does not change the engine's code-point deletion default. [Text contract](TEXT_RENDERING.md) records the sources, format diagnosis and editing behavior.

All **78 source checks pass**, including **108 shipped scripts**, exact font SHA, unchanged ASCII metrics, full sequence shaping with system fallback disabled, and actual UI Backspace events for family, skin tone, flags and combining accents: [source evidence](evidence/m5-font-checks.json). Actual native Compatibility rendering finds **1,718 / 875 / 907** visible emoji pixels per face with host fonts disabled: [numeric evidence](evidence/m5-font-native.json), [GPU readback](evidence/m5-font-native.png). Linux rendering CI now requires and preserves this gate.

The dirty local release Build 72 APK shows the [original invisible glyphs](evidence/m5-font-android-before.png) and [fixed glyphs plus whole-family deletion](evidence/m5-font-android-fixed.png) on the Android 15 ARM64 emulator. Package inspection finds the bundled font data, font licenses and ICU bytes. [Probe/package metadata](evidence/m5-font-android-metadata.json), the explicitly [failed default-deletion attempt](evidence/m5-font-edit-before.json) and [final actual Android KEYCODE_DEL result](evidence/m5-font-android-edit.json) retain exact APK distinctions. The final key leaves precisely `ab`; no profile is initialized by the fixed-string probe. The later credits-only source text change is not in that tested local APK.

A separate release-APK race and rematch again completes **16 finishes** across Android and seven native clients, matching complete authority/native standings against Android's parsed-row digests and committing exactly two Android receipts. [Actual results with visible emoji names](evidence/m5-font-android-results.png) and [cross-play summary](evidence/m5-font-mixed.json) identify the APK before the final shared editing refinement. Its unique QA profile is archived and processes stopped. This is emulator automation; physical IME, touch feel and thermal behavior remain open.

Build 70 passes remote CI but its publisher step defers to the newer build, so it has no release tag. Build **71** passes all remote gates, including native RSS probes on Linux/Windows/macOS and measured-worker HTTPS integration, and publishes all **18** files as [v0.0.71-dev](https://github.com/maccam912/racinggame/releases/tag/v0.0.71-dev). This font checkpoint awaits its own remote release. Cosmetic digest is now `64547c7923d7a7d0ab85f044ea1c6ed3c2f94d9c0d4789526d1eb714dedfea98`; gameplay content 4/protocol 5/save schema 1 remain unchanged.

The first ten-race soak retains a failed outcome: standings/80 finishes and all clear-road p95 distances pass (worst **0.0401 m**), but identical test drivers leave as few as 79 clear-road samples against the fixture's 500-per-race coverage guard. Repeated loading causes transient RSS peaks while retained RSS returns to baseline. A traffic-aware fixture and separately reported cycle high-water/retained memory measurements are being prepared; NET-01/PERF-01 acceptance is not claimed here.


## M5 — authoritative results survive worker retirement checkpoint

A real process/ENet fixture reproduces the old shutdown ordering: the worker queues its final standings, then exits on the next tick before `WirePeer.poll()` can transmit them. Both clients receive no result despite the authority printing one. The [failed reproduction](evidence/m5-retirement-before.json) retains that outcome. A retiring worker now continues polling and reliable delivery for **five seconds** after results, rejects fresh admissions, and never starts a rematch. Existing races continue toward their normal finish, with a fixed **ten-minute wall-time bound** that repeated retirement signals cannot extend. Race simulation/snapshots stop after the final result rather than continuing during results menus. Idle retirement and timed-out unfinished races still award no fabricated result. [Retirement contract](WORKER_RETIREMENT.md) describes the limits.

All **80 source checks pass**, including **108 shipped scripts** and the new retirement deadline/process gates: [full report](evidence/m5-retirement-checks.json). The actual shutdown fixture uses **eight clients**, 150 ms injected RTT, ±30 ms one-way jitter and **3% datagram loss**. A deliberately synthetic **1,952-byte** result traverses reliable fragments and arrives identically on all eight clients before exit. A late admission is rejected, the active race advances after retirement is requested, and all clients requesting Return/Ready/Start still produce exactly one race. [Fixed process/UDP evidence](evidence/m5-retirement-fixed.json) records the explicitly synthetic result boundary. Source CI preserves the worker/client evidence folders on failure.

The improved soak pilot separately passes two real races with at least **631 clear-road samples** per driver/race, worst p95 **0.0191 m**, and measured IPv4+UDP peaks below **3.6 KB/s upstream / 15.7 KB/s downstream**. A fresh ten-race repeat is running with the unchanged 500-sample and 0.25 m guards. Full soak, physical baseline devices, supervisor recovery/rolling deployment and publisher/hosting gates remain separate work. Gameplay content 4/protocol 5/save schema 1/cosmetic identity are unchanged.


## M5 — repeatable soak fixture checkpoint

The first [ten-race attempt remains failed](evidence/m5-soak-initial-failed.json): **80 finishes** and identical standings, worst clear-road p95 **0.0401 m**, but only **79** clear samples for the most crowded driver/race. A first traffic-aware [two-race pilot also remains failed](evidence/m5-soak-traffic-pilot-failed.json), improving coverage to 326 but exposing a collector exit ordering that omitted the last wire interval. Neither is relabeled as full acceptance.

The repaired collector records every check separately and captures a final pass after client exit. Independent proxy seeds avoid correlated impairment streams. A source-only paced traffic driver uses ordinary shared AI planning, normal snapshots and explicit target-speed variation; gameplay physics, car content, authority contacts and correction classification are unchanged. The 500-sample and **0.25 m** guards remain. The [final two-race pilot passes](evidence/m5-soak-paced-pilot.json) with a minimum **631** clear samples per driver/race, worst p95 **0.0191 m**, and measured IPv4+UDP traffic under **3.6 KB/s up / 15.7 KB/s down**. All 16 finishes match, no DNF/bots, all four car types, and both wire intervals are captured.

Memory reports now retain transient track-transition peaks and compare the same repeated loading/racing cycle's high-water marks through minute five and between minutes five/fifteen. Instantaneous baseline/end and retained growth remain separately visible, and the absolute 256 MB bound still applies. This avoids treating a low race-time point as an equivalent baseline for a repeatable loading peak; it does not establish continuous worst-track PERF-01. The full ten-race repeat is running at this checkpoint; physical baseline and named two-vCPU host gates remain open.


## M5 — managed supervisor recovery and overlapping pools checkpoint

The first supervisor signal now stops allocation/public readiness and drains only its owned workers while keeping private HTTP alive; a second signal forces that pool to stop. Existing races retain the ten-minute/five-second worker contract. Exclusive private/public binding precedes recovery mutation. Surviving workers authenticate and drain on restart; a private-link outage retires once after 15 seconds. Reconciliation preserves unknown busy IPv4/IPv6 ports, signals only owned children and reclaims free reservations. A fixed operator event reports overdue unknown ports. Shared host capacity counts all generations.

SQLite **service schema 3** persists owner endpoint, drain deadline and authenticated numeric performance; admission reads shared fresh reports across supervisors. Historical schema-1/2 fixtures preserve encrypted identity bytes and bearer sessions through migration; future database versions remain refused. The game save schema stays **1**. The new filesystem-only `drain` command cannot reopen or extend retirement. [Lifecycle/rollout contract](SUPERVISOR_LIFECYCLE.md) describes the exact scope and separate log folders/private listeners/UDP ranges.

The actual crash fixture exposed a second lifetime issue: `io.Discard` created parent-owned output pipes, and the worker stopped after supervisor SIGKILL. [Failed crash evidence](evidence/m5-supervisor-crash-before.json) remains failed. Direct null-device handles now keep the actual worker/race alive through the tested kill/restart. Allocator graceful completion also waits for database cleanup callbacks.

All **81 source checks pass**, including **108 shipped scripts**, the real fifteen-second private-link loss and eight-client fragmented retirement: [full source report](evidence/m5-supervisor-checks.json). The complete Go race-detector suite and vet pass, covering encrypted/bearer migration, cross-supervisor performance, global capacity, idempotent drain, private-owner recovery, IPv4/IPv6 port retention and owned-only termination: [Go/fixture hashes](evidence/m5-supervisor-go.json). The full actual [HTTPS menu flow](evidence/m5-supervisor-https.json) remains green.

All four actual [local process scenarios pass](evidence/m5-supervisor-matrix.json): idle operator drain, graceful active race, SIGKILL/restart and overlapping old/new private/UDP pools. The same race/guest identities and identical synthetic final rows reach both clients, the new supervisor accepts the old bearer, shared host capacity rejects an extra allocation, and every case ends with **zero worker rows / no cleanup issues**. The result is deliberately forced by a fixture gate after real retirement; no genuine lap time, profile record or public hosting acceptance is claimed. A new Linux CI lifecycle job gates publication.

Build 73 passes remote gates and publishes all **18** files as [v0.0.73-dev](https://github.com/maccam912/racinggame/releases/tag/v0.0.73-dev). Build 72's successful publisher defers to 73. Build **74 remains blocked** by a [synthetic-fixture speed-guard mismatch](evidence/m5-retirement-ci74-failed.json): all eight results arrived, one car reached 14.7004 m/s before the forced finish. The short retirement mode now requires movement above 5 m/s plus a received result; ordinary driving fixtures retain 15 m/s. The repaired full source/process gates pass locally and await CI. Gameplay content 4/protocol 5/game save 1/cosmetic identity remain unchanged. The full standard two-lap soak is still running; physical baselines, operated deployment/backup drills and publisher gates remain open.


## M5 directory backup and restore checkpoint

The compiled operator CLI now snapshots a live WAL database into a new private backup folder, verifies integrity/foreign keys and decrypts each guest credential with the original separately stored keys. A synchronized manifest seals the byte count, SHA-256, schema and opaque key identity. Existing folders, missing/future source databases, wrong keys and incomplete/corrupt snapshots are refused. [Commands and operator drill](DIRECTORY_BACKUPS.md) describe the exact Linux/local-filesystem contract.

Restore publishes only to a new database path, refuses existing SQLite sidecars, migrates an isolated copy of historical schemas 1/2 to service schema 3, and preserves original backup bytes. Guest identity ciphertext and bans survive. Worker/room leases, pending tickets, authentication nonces and bearer sessions are cleared so a rollback cannot resurrect live processes or replay state. Protected guest credentials can authenticate again. Ordinary schema upgrade session continuity remains separate.

The complete Go race-detector/vet suites pass, including 25 repetitions of a live-WAL concurrent-transaction snapshot. The actual compiled CLI drill registers two temporary guests, backs up the running service, restores, restarts, rejects an old nonce and banned guest, and authenticates the original identity: [CLI evidence](evidence/m5-directory-backup-cli.json), [checks](evidence/m5-directory-backup-checks.json). It removes its temporary keys/data; remote CI now requires this drill.

Build **75** passes source verification but fails while SDK Manager downloads the pinned Android NDK, before compilation: [failure evidence](evidence/m5-ci75-android-download-failed.json). CI now retries the same pinned Android package installation at most three times. No release for 74/75 is claimed; latest confirmed publication remains Build 73. The full two-lap soak remains active at this checkpoint. Operated daily/off-host backups and monthly production restores, physical-device baselines and public deployment remain open. Gameplay content 4/protocol 5/game save 1/cosmetic identity are unchanged.


## M5 full eight-client impairment soak checkpoint

The actual eight-client, ten-race **two-lap** source soak passes every guard in **1,699.7 seconds**: **80 finishes**, no DNF or bot replacements, stable guest identities, identical standings on all clients, all four normal cars, both courses and no large racing control events. Eight independent UDP proxies each apply 50±20 ms per direction and 1% datagram loss, including ACKs/retransmissions. All clients cleanly exit and every owned proxy/process is cleaned up: [full evidence](evidence/m5-soak-ten-two-lap.json).

Every driver/race has at least **1,138 clear-road samples** (203,921 total); worst per-driver/race p95 correction is **0.0262932 m**, below the unchanged 0.25 m guard. Maximum racing IPv4+UDP averages are **3,716 B/s upstream / 15,656 B/s downstream**, below 10,000/40,000. Measured five-to-fifteen-minute repeated-cycle peak growth is **0.0574%** (171,311,104 → 171,409,408 bytes); retained growth is 0.0737%. Absolute sampled RSS peaks at **171,458,560 bytes** through the whole run. These are this development Mac's measurements, separate from continuous worst-track PERF-01, the specified two-vCPU stripped Linux host and physical Android thermal/control acceptance.

The prior one-lap full repeat remains **failed** for three driver/race cases below the unchanged 500-sample coverage requirement, despite 80 finishes and passing accuracy/wire/memory checks: [preserved failure](evidence/m5-soak-one-lap-coverage-failed.json). A two-lap pilot passes before this final run: [pilot](evidence/m5-soak-two-lap-pilot.json). The fixture now defaults to two standard laps to collect sufficient observations; game handling, AI and correction/contact thresholds are unchanged. Other lobby fixtures retain their one-lap default. Gameplay content 4/protocol 5/game save 1/cosmetic identity remain unchanged. Physical-device, documented server-host, public deployment and publisher acceptance remain open.


## M5 local results visibility checkpoint

Results now reveal the highlighted local race row after layout without stealing keyboard/controller focus from footer actions. A deferred request from an old page cannot scroll its replacement. Failed-save messages and Retry keep priority at the top, rather than being scrolled away.

The exact-size phone fixture first reproduces rank 8 below the viewport at 125% UI scale: [before](evidence/m5-results-before.json). All **18** phone/tablet/desktop, 100/125/150% scale and first/eighth-place combinations pass after the change, along with failed-save priority and stale-page guards: [headless](evidence/m5-results-headless.json), [native](evidence/m5-results-native.json). The actual Compatibility renderer captures the local row visible at 150% on a 2400×1080 phone-sized viewport: [image](evidence/m5-results-phone-150.png). These are production UI with fixed synthetic completed rows, not physical Android or earned gameplay results. Required CI now includes this rendered fixture.

All **82 source checks** pass, with **108 shipped scripts** loading, including the actual impaired eight-client retirement integration: [full checks](evidence/m5-results-checks.json). Gameplay content 4/protocol 5/game save 1/cosmetic identity remain unchanged. Current-APK follow-up, physical devices, specified server-host performance and public/publisher acceptance remain separate gates.


Current-APK follow-up: installed release APK **78**, built from clean commit `801277a`, passes two actual eight-player races at **150% mobile UI scale** on the owned Android 15 ARM64 phone emulator. All **16 finishes** match authority/native/Android result digests, preserve the same eight identities and all four cars, and commit exactly two Android races. The actual eighth-place local row is immediately visible above the action buttons: [APK evidence](evidence/m5-results-android78.json), [Android image](evidence/m5-results-android78-150.png). Only the new QA profile is archived; all owned native processes are cleaned up. Physical phone/tablet, cellular, thermal and human control acceptance remain open.

Builds 76/77 were superseded and cancelled after the combined checkpoint was pushed as Build **78**; no release is claimed for those runs. Build 78 and the separate manually dispatched Linux ten-race soak (run 79) are in remote CI at this checkpoint. Usage was checked at **54% weekly remaining**, above the requested stopping boundary.


## Server distribution and executable acceptance preparation

The Linux server ZIP now includes the exact pinned, static Go **1.27.0** x86-64 operator binary, its dependency licenses, embedded/sidecar identity, Caddy examples and recovery/backup/performance runbooks. The stripped Godot worker retains its embedded project. New [bundle setup instructions](SERVER_PACKAGE.md) cover exact build compatibility, unprivileged operation, HTTPS/private/UDP boundaries, host capacity, persistent data and explicit community hosting. External release naming/checksum/metadata files remain the same six-target **18-file** set. Client packages do not gain the service or operator data.

`pacific-directory version` reports public embedded build provenance plus the actual Go runtime and service schema without reading keys. Go race-detector/vet and Python suites pass. The actual source CLI restore drill still passes. A local server export, ZIP identity/hash/runbook/license/no-key checks and the shipped operator plus two byte-identical repeat cross-builds pass: [package evidence](evidence/server-bundle-local.json), [CLI evidence](evidence/server-package-source-cli.json). The matching Linux native adapter is retrieved from the verified native CI artifact; it is not rebuilt as a Mac binary. These are cross-build/export checks, not Linux execution.

Required native release CI now executes the **bundled** operator, compares its runtime/sidecar/game identities and binary checksum, and runs the isolated backup/restart/auth drill using that executable. It also starts the **exported** worker from the extracted bundle with no source project path and runs two actual impaired eight-client, two-lap races. Reports retain all per-race correction/wire checks; this short artifact check does not replace the fifteen-minute memory or full ten-race soak. Other desktop package startup checks remain required. Linux execution of these new gates awaits this checkpoint's CI.

This prepares distribution while M5 physical phone/tablet, human controls and the specified server-host performance remain open. OCI images, operated public regions/daily backups/monthly drills and publisher signing/store acceptance remain separate work. Gameplay content 4/protocol 5/game save 1/cosmetic identity are unchanged.


## M5 recovered-worker shutdown checkpoint

A new actual-process regression exposes early shutdown after recovery: killing one supervisor leaves its worker racing, but the replacement's first shutdown signal previously saw zero owned children and immediately closed private supervision. [Preserved failure](evidence/m5-recovered-drain-before.json) records the reproduced exit and complete fixture cleanup.

Shutdown now stops new allocations, drains the existing workers associated with that private endpoint (including recovered/legacy rows), and waits for both those scoped rows and allocator callbacks to clear. Other private pools remain outside the wait. The earliest ten-minute deadline is preserved, the second signal still forces only owned children, and unknown PIDs are never signaled. Query/reconciliation failures now produce an operator error after cleanup.

All **five** real-process scenarios pass: idle drain, normal active drain, supervisor SIGKILL/recovery, overlapping pools and shutdown of the replacement while its recovered worker is still active. Each preserves its applicable race/guest/result contracts, ends with **zero worker rows**, deletes its temporary keys and has no cleanup issues. Go race-detector/vet also pass: [matrix](evidence/m5-recovered-drain-matrix.json). CI automatically includes the new fifth mode through the existing required lifecycle job. Forced synthetic finishes validate lifecycle/transport, not genuine lap times or saved results. Physical devices and operated hosting remain open; game compatibility identities are unchanged.

Builds 78 and 80 pass remote CI, while their publishers defer to the newer workflow, so neither has a published release. Build 81's server-bundle gates and run 79's separate Linux full soak remain active at this checkpoint. Latest confirmed published release remains Build 73.


## Dedicated release logging repair

Build **81** passes the bundled operator's actual Linux identity and backup/restart/auth drill, and all ordinary desktop package checks. Its new exported-worker race gate remains **failed**: the release worker stays alive but its stdout log remains empty through the 15-second readiness deadline. [Preserved CI evidence](evidence/server-package-ci81-failed.json) separates the passing executable/drill checks from failed live worker observation; no Build 81 release is claimed.

Dedicated-server feature overrides now flush printed stdout and disable automatic engine file logging. This makes bounded readiness/numeric evidence available immediately and avoids workers contending for a shared implicit file log. Ordinary clients keep their existing logging settings; supervisor structured logging remains bounded. A new artifact-only settings probe checks the effective release configuration before the native worker races.

An actual ad-hoc signed **macOS dedicated release** reports the three expected settings, emits readiness within **0.177 seconds while still alive**, and emits periodic numeric performance before termination: [native evidence](evidence/server-release-logging-mac.json). All 108 shipped scripts compile; Linux exported race validation awaits the repaired CI. This is runtime logging/packaging work, with unchanged gameplay content 4/protocol 5/game save 1/cosmetic identity. The ongoing separate full Linux source soak remains a different gate.


## Linux full soak and OCI hosting preparation

The independent manually dispatched **Linux x86-64 full soak (run 79)** passes every guard: **80 finishes**, identical standings/stable identities, all four normal cars, no DNF/bot replacement or large racing control events, and all ten wire intervals. Every client/race has at least **647 clear samples** (185,249 total), with worst p95 **0.0257093 m** under the unchanged 0.25 m boundary. Repeated-cycle peak RSS grows **1.4607%** between the comparable five-/fifteen-minute windows (127,029,248 → 128,884,736 bytes), below 5%; retained growth is negative. Wire and absolute memory guards pass, with no cleanup issues: [Linux CI evidence](evidence/m5-soak-linux79.json). This uses the pinned editor/source authority and native Linux adapter on the CI host, separate from exported-worker execution, a specified dedicated host and physical Android.

The OCI runtime definition now consumes only a checksum-verified server ZIP, pins Ubuntu/Caddy images, keeps keys/data outside layers, uses an unprivileged service, and retains a stable init/restart wrapper. Local readiness probing has a bounded three-second/no-redirect/loopback contract. The [image/region runbook](CONTAINER_HOSTING.md) covers host networking, persistent volumes, HTTPS/UDP/private boundaries, graceful retirement, rolling pools, backup drills and registry permissions. No public domain, service schedule or production region is configured.

All **82 source checks** pass again, as do **nine Python tests**, Go race/vet, shell syntax and YAML parsing. A local owned-process wrapper test reproduces child SIGKILL/restart and verifies its first shutdown signal waits for delayed child completion. The new image context prepares successfully from a local Linux server export, checks matching identities/checksums and contains no operator keys/database: [preparation](evidence/container-local-preparation.json), [source checks](evidence/container-source-checks.json). Docker is unavailable on this Mac; **no locally built/running image is claimed**.

Required Linux image CI will build that context, validate Compose, run eight actual signed clients through one genuine two-lap race, kill/recover the directory child while preserving the worker process, and stop the image while its recovered race remains active. Only after eight matching finishes/clean stop and all other gates does the publisher push the exact tested image and its immutable registry reference alongside the usual 18 development files. Image execution and publication await this checkpoint's remote CI. Build 83 separately validates the repaired dedicated release logging; Builds 81/82 remain blocked by the pre-repair live-output gate. M5 physical hardware, the specified server-host benchmark, operated regions/backups and publisher/store acceptance stay open. Compatibility identities are unchanged.


## Exported server and published OCI validation

Build **83** passes the repaired artifact-only dedicated logging probe, the shipped Linux operator identity/live-backup drill and eight actual clients through two genuine two-lap races against the exported Linux worker: [artifact evidence](evidence/server-package-ci83.json). Builds 81/82 retain their pre-repair live-output failures; Build 83's publisher defers to the newer workflow.

Build **84** passes all required gates and publishes all **18 files** as [v0.0.84-dev](https://github.com/maccam912/racinggame/releases/tag/v0.0.84-dev). Its exact tested image is anonymously retrievable at `ghcr.io/maccam912/pacific-rush-server@sha256:45c8797205097226fdf1a555eb462f135e728a5c1fbaa085649f0698d7d7660b`. The actual Linux image under a two-CPU/1 GiB cgroup completes eight genuine two-lap finishes with identical rows, preserves the same worker/eight identities through directory SIGKILL/recovery, and waits for the recovered active race during graceful stop. Exit is zero with no cleanup issues: [image evidence](evidence/container-ci84.json). Numeric samples captured around restart are partial 15/20-second windows, separate from full-window performance or the specified cloud-host benchmark. No public region or production backup schedule is claimed.


## M6 original application icons checkpoint

The original coupe/sunrise icon now has authored desktop sizes, native Windows ICO/macOS Retina ICNS, separate Android adaptive foreground/background/themed layers and an opaque 512-pixel store icon. The actual foreground/themed alpha stays inside the specified 66 dp safe disk and exceeds the 48 dp minimum mark dimensions: [geometry](evidence/app-icon-geometry.json), [mask preview](evidence/app-icon-masks.png). The [asset authoring contract](APP_ICONS.md) records reproducible generation, licenses, hashes and platform requirements.

All **83 source checks** pass, including actual engine geometry validation and all 108 shipped scripts: [checks](evidence/app-icon-checks.json). Local development-signed Build **85** exports pass actual package-resource checks for [Windows](evidence/app-icon-package-windows.json), [macOS](evidence/app-icon-package-macos.json), [APK](evidence/app-icon-package-android.json) and [AAB](evidence/app-icon-package-android_aab.json). Windows embeds all six standard authored PNG sizes; macOS contains the exact authored ICNS; Android compiled manifest/resource references select the three adaptive layers. The installed APK's native Android 15 emulator app-info page shows the actual masked icon: [native render](evidence/app-icon-android85.png). These local exports have dirty-tree provenance based on `35d9cfd`; remote validation awaits this checkpoint's push. No physical/OEM/storefront acceptance is inferred.

Cosmetic identity changes to `ea3d4cf4170d1cfbe539cba79dad342fd48d319d64b23653bfb4e5530d9bca96`. Gameplay content **4**, protocol **5**, game save **1** and gameplay digest remain unchanged. Six actual gameplay screenshots per platform family, factual store copy, authenticated deletion/operator support, publisher details and physical-device acceptance remain separate M6 work.


## M6 gameplay capture and store copy preparation

The exported client can now capture an actual ordinary Quick Race on a named track after a specified number of racing ticks, using a fresh diagnostic profile, seven Medium opponents, a fixed seed, Near Chase and Medium graphics. The production loading/warmup path, simulation, camera and normal HUD remain active. A hash-bound sidecar records the real export identity, vehicle/race state, graphics settings and world/output dimensions. The [capture helper and factual copy](STORE_COPY.md) distinguish this diagnostic driving from human/physical acceptance and leave publisher/support/privacy/rating details open.

The first actual macOS source render reaches 1,200 racing ticks (20 simulation seconds), 49.22 m/s and the Palm Bay course at 1920×1080 with the normal eight-car racing HUD; no vehicle pose is injected. All 108 shipped scripts, mode/ghost objectives, real menu navigation, staged loading/cancellation and accessibility fixtures pass. Six-course exported desktop/Android captures await the new package; no storefront submission or physical-device proof is claimed. Game compatibility identities are unchanged.


## M6 authenticated regional data-request checkpoint

Settings → Data now sends a twice-confirmed deletion request to the selected regional operator using the existing protected guest/session. No unused online identity is registered for the request. The HTTP body cannot choose another guest. Concurrent/repeated submissions retain one durable receipt and original timestamp; the UI reveals **pending operator action**, preserving local saves/settings. Cancellation, invalid response, missing identity and failed authentication remain distinct from successful receipt. [Operator/request contract](DATA_DELETION_REQUESTS.md) explicitly leaves actual fulfillment/retention policy to operated deployment.

The filesystem-only `deletion-requests` CLI pages receipt/guest/time mappings without exposing names/secrets/tokens. Service schema **4** adds the queue; frozen schema-1/2/3 fixtures migrate with encrypted identity/session continuity. Verified live-WAL backup/restore retains pending requests while clearing ephemeral worker/room/auth state. The server bundle includes the new runbook; all its relative documentation/evidence links now resolve after extraction.

All **83 source checks** pass, with **108 shipped scripts**. Go race/vet pass, including strict TLS/session binding, expired/forged bearer rejection, arbitrary-guest/null/trailing-body rejection, 32 simultaneous duplicate requests and operator pagination. The [actual compiled CLI drill](evidence/data-request-cli.json) proves lookup and request persistence through backup/restore. The [full real HTTPS menu fixture](evidence/data-request-https-menu.json) passes both dialog button callbacks, stable repeated receipt, preserved local data and subsequent explicit local reset. Its native 150% [receipt render](evidence/data-request-150.png) is reviewed; the UI reveals it above Back. [Source evidence](evidence/data-request-source-checks.json) precedes the final focused confirmation/receipt-layout rerun, which also passes. No production erasure or operated policy acceptance is claimed.

Build **85** passes all remote icon/resource/native gates; its publisher defers. Build **86** passes all remote gates and publishes all **18 files** as [v0.0.86-dev](https://github.com/maccam912/racinggame/releases/tag/v0.0.86-dev), with tested OCI digest `sha256:b5d5b2c212f0c4ae4f9c8609df7bdb970f79f631217d573b74693f4e0c5d0609`. This request checkpoint awaits its own CI. Game content 4/protocol 5/save 1/cosmetic identity remain unchanged.

The actual clean-commit Build 86 exports also complete [all six desktop and Android gameplay baseline captures](evidence/store-baseline86). Eleven capture at tick 1,200; desktop Summit captures at tick 5,360 after delayed GPU readback. The measured later timestamp is preserved. Capture now holds the genuine simulation instant before awaiting GPU readback. These unretouched baseline images precede the owner's approved illustrated billboard, speed/verticality and physics-tuning direction; final store captures will be refreshed after that pass. Physical checks are optional owner follow-up under the updated scope.


## Owner-approved illustrated foliage and arcade camera

Five original image-generation assets now render repeated palms, citrus trees, redwoods, sage shrubs and bunchgrass as cylindrical billboard cards. The saved source PNGs, prompts/provenance, exact byte hashes, alpha-derived UV bounds and mipmapped imports ship in the repository. Existing 3D cars, roads, barriers, buildings and major landmarks remain. Two-triangle instanced cards have conservative rotational bounds and near soft footprints; camera-facing decoration adds no driving collision. [Art/runtime contract](BILLBOARD_ART.md) records the implementation and engine references.

Near Chase moves to **5.0 m behind / 1.65 m high**. Dynamic vertical FOV expands by up to **18°** over 15–70 m/s, approaches at 6/s and caps at 95°. Reduce Motion/Dynamic Off retain a fixed selected base. Foliage moves nearer the roadside and palms use 16 m spacing. This step is presentation only; the newly authorized faster handling and stronger elevation profiles follow as a separate content version.

All **84 source checks** pass, including **109 shipped scripts**, route/collision immutability and the actual impaired retirement fixture: [source checks](evidence/billboard-source-checks.json). The actual macOS [five-species renderer test](evidence/billboard-native.json) passes all **20 approach views**, with silhouette area varying under 2.5%; [headless evidence](evidence/billboard-headless.json) separately validates hashes/mipmaps/instancing/bounds. Camera expansion/cap/Reduce Motion/Off and existing boom/shake/recovery fixtures pass. The actual native adaptive/memory renderer and all-six-course pre-grid shader warmup remain green. Memory pressure clears reusable billboard references while active scene materials/textures and driving collision remain live. Required software-GL CI now repeats the approach-angle render gate.

Cosmetic digest becomes `b7dd3a0f0323e9798b08cea44ecb2f3aaf63719592b3f6181195db4a8ae5a4dc`. Gameplay digest `538d6c1dec5d175634a818fb0b127c51c85439ffe29ad919aa653e54214d9170`, content 4/protocol 5/save 1 remain unchanged. These source/native checks precede the new exported desktop/Android follow-up. Source capture metadata now explicitly distinguishes editor execution from exported templates, so an ignored stale build.json cannot masquerade as an export identity. Physical validation remains optional owner follow-up.

The actual current source client renders the new desert shrubs/grass and lower camera in a normal eight-car Quick Race at exactly 1,200 racing ticks: [Canyon render](evidence/billboard-canyon-source.png), [source-only metadata](evidence/billboard-canyon-source.json). This intentionally has no export build identity; exported package follow-up is separate.


## Exported illustrated-art follow-up and transition baseline

Clean-commit local Build **88** (`f6a5769`) completes all six actual exported races/captures per platform family: [desktop](evidence/billboard-export88/desktop/summary.json), [Android 15 ARM64 emulator APK](evidence/billboard-export88/android/summary.json). Every capture reaches exactly **1,200 racing ticks**, records `exported_template`, matches the clean embedded build/cosmetic identities and retains the normal HUD (including actual mobile touch controls). The six original courses and all four cars appear. Images are unretouched 1920×1080 / 2400×1080 outputs. They validate this presentation checkpoint, not the upcoming faster handling/elevation revision or human driving feel.

Build **87** passes remote gates and publishes all **18 files** as [v0.0.87-dev](https://github.com/maccam912/racinggame/releases/tag/v0.0.87-dev), including the schema-4 request operator and real backup/restore drill. Build 88's new native/software-GL foliage gate is still running at this checkpoint.

Before changing gameplay content, the exact content-4 configurations plus a frozen profile/record/ghost/Cup/in-progress race fixture are saved under `tests/fixtures/content4`. Their explicit synthetic-record boundary and byte hashes are retained for transition checks. The new candidate profiles and car parameters remain prototypes at this checkpoint; no content-5 release is claimed yet.

## Content 5 — faster handling and steeper courses, validation in progress

[The tuning revision](ARCADE_TUNING.md) documents the four revised cars, six new
elevation profiles (49–103 m ranges, up to 23.9% grade), longer Summit flight,
28 original 3D structure frames, slope-following cars/camera and conformed bridge
artwork. All X/Z control points and 30 named landmarks remain. DESIGN.md v1.4
publishes the new numeric contract. Content 4 archive bytes remain frozen.

The intermediate .70 Summit candidate passes 360 field races / 2,880 finishes,
zero DNFs/recoveries, and an automated six-course three-lap car comparison has
aggregate median times within 0.9%. Outside-line 95 m/s testing then requires
the final .68 ramp: all 60 actual-course landing cases pass, with no recovery
and at most .85 s airtime. The 15 straight slope/speed fixtures also pass. Final
full AI, source, native and network evidence will be recorded after completion.

Build 89 exports all platforms but its packaged Linux worker gate fails: one
clear-road sample count is 476 against the required 500 in a two-lap race. All
16 finishes, standings, accuracy and wire checks pass; it is not published. The
next gate uses three laps, retaining the 500-sample and .25 m p95 requirements,
and prints the actual nested failure into CI logs. Longer CI soak likewise uses
three laps. Build 88 remains the latest verified public release with 18 files.

All **89 source commands pass** on the final content-5 configuration. All **111
shipped scripts compile**. The actual native six-course GPU warm-up/readback,
retry/cancel/background and ENet Loaded checks also pass. Native views of all
six new structure sequences were inspected, including the repaired Summit
viaduct. [Source/numeric/render evidence](evidence/content5/) retains the current
gameplay and cosmetic identities. The final full AI run, ten-race impaired soak
and matching exported Android/desktop follow-up are still running or pending.

The **final** content-5 full AI matrix also passes: 360 field races, **2,880
finishes**, zero DNFs and zero recoveries, with strict Easy/Medium/Hard ordering
for all four cars on the flat single-car reference fixture. Gameplay digest is
`4eaef43b6dd7efb40414a23b8f84f4f2902417f8e3a9d0d85bbeced354b3e69a`;
cosmetic digest is
`b61a53bf151b3b69e8eb5a7f021924dc32a4e0de10f1db3a31ea91d932e46e99`.
[Final AI evidence](evidence/content5/ai-summary.json) retains its scripted-input
boundary. Clean local Build 91 macOS and Android packages embed commit `70015cf`
and these identities. Their actual cross-play/capture follow-up is in progress.

A native capture sometimes quit before the audio mixer retired playback
references. Diagnostic capture now uses the existing .5-second stopped-audio
quit sequence; the capture helper rejects engine/resource-leak errors. Capture
metadata records horizontal and 3D speed separately and includes identities even
for clearly labeled editor-source captures.

All six actual native rendered eight-car races finish with all eight cars and no
DNF. The installed clean Build 91 release APK also completes **two two-lap
eight-player rematches** against seven native clients, at 150% mobile UI scale,
with equal authoritative standings and all 16 human finishes. This is Android
15 ARM64 emulator cross-play, not physical or impaired-network evidence.
[Native races](evidence/content5/native-course-races.json) and
[APK cross-play](evidence/content5/android91-crossplay.json) retain their exact
identities. The longer independent three-lap impaired soak continues.

## Content 5 — completed race/network checkpoint and painted travel signs

The final native macOS **ten-race / three-lap / eight-client** impairment matrix
passes all 11 checks: **80 human finishes**, identical standings, 214,761 clear-road
samples (minimum 1,000 in any client/race), worst clear p95 **.03935 m**, wire
budgets and no engine errors. Native worker RSS peaks at **171,163,648 bytes**;
the 5–15 minute high-water growth is **−0.201%**. This cycles Palm Bay/Citrus on
this computer and remains separate from the named cloud-host/worst-track target.
[Raw soak evidence](evidence/content5/macos-ten-race-soak.json) retains its source
worker/dirty-checkpoint provenance; gameplay sources were held at the final
`4eaef43b…` configuration throughout. New fixture reports now record and verify
the computed gameplay identity both before and after execution.

Linux CI's six-course AI jobs also complete 360 field races / **2,880 finishes**
with zero DNFs/recoveries on the same gameplay digest, plus the 12 single-car
ordering cases. [Raw per-track evidence](evidence/content5/ci91-linux-ai/) is
retained independently of the parent Build 91 workflow's contact-sample failure.
The contact gate keeps its 1,000-sample / 1.5 m p95 requirements and now runs
420 seconds. The local real-fault run passes **104 distinct contact episodes**,
1,576/1,204 contact samples, and p95 **.5993/.6859 m**.
[Contact evidence](evidence/content5/macos-contact420.json) labels the scripted
reset/contact fixture separately from ordinary completed races.

**Build 92** passes all remote gates and publishes all **18 files** as
[v0.0.92-dev](https://github.com/maccam912/racinggame/releases/tag/v0.0.92-dev),
with tested OCI digest
`sha256:2fe8866db9560d38c93beaeac964707a2054730577da55bfd7ae467de216d187`.
The clean local Build 92 exports complete all six actual ordinary-race captures
on desktop and Android, exactly 1,200 racing ticks, with the proper HUD/touch
controls and no engine/resource-shutdown errors.
[Desktop/Android capture evidence](evidence/content5/export92/) retains each
platform's exact embedded build identity.

Six further original painted course posters now sit on **18 static 3D frames**.
All PNG source bytes, full built-in image-generation prompts and hashes are
frozen; no image was repainted or resampled. Decorative vegetation leaves short
sightlines to the panels. Cars, buildings and structures stay 3D; rotating
foliage billboards remain separate. [Authoring details](ROADSIDE_POSTERS.md).
All **90 source commands** pass, the full Python suite passes **13 tests**
(including four failure-report cases), and actual native six-course poster views
and all-six shader/readback/ENet readiness checks pass. These source signs await
their own exported Android/desktop checkpoint. Physics content 5/protocol 5/save 1
remain unchanged; cosmetic digest becomes
`acc55b771495e4121c7fec86aec7fcd5f7a93102642b5fcaf85e525f20c27177`.

Network fixtures now give every invocation its own directory, preserve failed or
partial client reports, terminate only owned processes, save timeout/engine-error
metadata, and refuse stale or changing gameplay identities. Historical failed
runs are not overwritten or relabeled. Official regions remain unconfigured.

All six native sign approaches and the actual Build 91 enlarged Android results
were visually reviewed. Build 92's exported mobile Summit and desktop Redwood
views retain readable HUDs and slope-following cars. Two normal-pace scripted
driving clips preserve the source/build provenance and show Palm Bay's climb/drop
and Summit's flight: [footage and reproduction notes](evidence/content5/footage/).
The required ten-race Linux soak now automatically runs after gameplay identity
changes and gates publishing; it can also be requested manually. Cosmetic-only
pushes retain the ordinary source, rendering, network and packaged-race gates.

## Original rock geometry and shared-atlas follow-up

Canyon buttes now have stepped strata and Summit has uneven paired ridges, with
explicit three-level LODs. Original mathematical wood/stone/strata detail remains
inside the shared palette atlases. Every vertex at all three levels fits the
existing conservative road-clearance envelope; driving geometry is unchanged.
The 47 GLBs now retain UVs/material slots without duplicate embedded atlas images,
reducing geometry files from 3,929,256 to 3,072,752 bytes. This is a file-size
measurement, not a runtime-memory claim. [Authoring and numeric details](SCENERY_DETAIL.md).

All **90 source commands** pass again, including the 13 Python cases and actual
engine geometry checks. Native views of all 47 assets at all three LODs and the
Canyon/Summit road approaches were inspected. All-six native shader warm-up,
readback and real ENet Loaded/retry/cancel/background checks also pass:
[source/render evidence](evidence/scenery-detail/). Cosmetic digest becomes
`442367da36de66721bbb1ac5b6f666880ab372f9ede98afa1be8573399ecbb74`;
gameplay remains `4eaef43b…`, content 5/protocol 5/save 1. The capture helper now
accepts an explicit expected tablet resolution and validates it without resizing.
Matching exported phone/tablet/desktop follow-up remains pending at this point.

## Exported detail checkpoint and degraded network tier

Build **93** passes remote CI and publishes all **18 files** with the painted
signs as [v0.0.93-dev](https://github.com/maccam912/racinggame/releases/tag/v0.0.93-dev).
Its tested server image is
`ghcr.io/maccam912/pacific-rush-server@sha256:0b7ebf20f1f8599b406d5e8d8fe7eef0bab4bd87da7296e64fa784c47ed1f9b6`.
Build 94's detailed-scene remote release gates are still completing.

Clean local Build **94** embeds commit `69e349b`, gameplay `4eaef43b…` and cosmetic
`442367da…`. All **18 actual exported captures** pass: six 1920×1080 macOS,
six 2400×1080 Android phone and six 2560×1600 Android tablet. Seventeen captures
hold racing tick 1,200; tablet Palm Bay holds 1,201 after a two-tick presentation
interval. The genuine timestamp is retained. Medium graphics, native HUD/touch
controls and ordinary seven-opponent Quick Races remain active; no capture has
engine or shutdown-resource errors. Representative tablet Palm/Redwood, desktop
Summit and phone Marina views were inspected. [Export evidence](evidence/detail94/).

The actual phone update from Build 92 and tablet update from Build 55 use the same
verified signing certificate and retain their app UID and **all 31/20 existing
file bytes**, respectively. APK hashes match the installed packages. This
byte-preservation check occurs before launch and is separate from source save
migration, clean install or uninstall/reinstall. Only newly created capture
profiles are archived afterward. [Phone](evidence/detail94/phone-update.json) and
[tablet](evidence/detail94/tablet-update.json) retain exact versions and hashes.

The refreshed real-UDP degraded tier adds **125±30 ms each direction / 8% loss**.
Both clients complete three laps with identical two-human results and no DNF;
1,368 active 10 Hz quality observations per client show the poor tier. Clear-road
p95 corrections are **.04684/.05041 m** over 2,471/2,451 samples. Five/three
actual remote presentation samples need more than 150 ms prediction and remain
capped; buffers never exceed 20 snapshots. One initial liveness timeout resumes
its same slot before GO. This is automated movement and bounded presentation,
not a human degraded-network feel guarantee. [Raw evidence](evidence/network-degraded-content5.json).
Required CI now includes this fourth network scenario.

[The current acceptance index](ACCEPTANCE.md) maps all 32 required rows to actual
source/evidence and identifies human, emulator, hosted-region and publisher
boundaries. A separate live, normally paced six-course graphical scene/memory
soak is in progress; movie output and engine-smoothed simulation deltas are not
used to claim real frame timing.

Build **94** subsequently passes every remote gate and publishes all **18 files**
as [v0.0.94-dev](https://github.com/maccam912/racinggame/releases/tag/v0.0.94-dev).
Its tested server image is
`ghcr.io/maccam912/pacific-rush-server@sha256:20fcd2a6c8fa39b534e23bf2c73152e8ce7925ee179c7cf9419309572c786158`.
The exact published macOS/APK packages and their sidecars/checksums have also
been downloaded for separate artifact execution; that follow-up is pending.

The 90-command source matrix passes again with the new real-traffic quality and
remote-presentation observations. A subsequent targeted native Data-page fixture
and all 112 shipped-script compilation also pass. Settings → Data now explains
local identity loss and Android uninstall behavior. The 150% phone-sized native
[render](evidence/installation-preparation/local-identity-phone-150.png) is
reviewed; its existing reset-failure/data-preservation and successful retry checks
remain green. [Check logs](evidence/installation-preparation/) preserve the scope.
The actual native Keychain sequence passes seven cold-process probes, now
including absence before writing and after erasure. Android's new absence check
also verifies that the test-scope KeyStore alias is absent; its fresh-install/
uninstall/reinstall run is prepared in the new `pacific_rush_install_95` AVD and
awaits the matching APK. Existing phone/tablet app data is outside that fixture.

The completed [live graphical soak](GRAPHICAL_SOAK.md) finishes **12 races / 96
cars**, all six courses twice, without DNF or engine/shutdown errors. Across
44,699 racing draw intervals, wall-clock p95 is **18.497 ms**, p99 **22.324 ms**;
all four >33 ms intervals, including a **1.773 s maximum**, are retained. Native
RSS peaks at **688,226,304 bytes** with **2.8803%** comparable five-/fifteen-minute
cycle high-water growth. Other apps/emulators were active. A temporarily occluded
loading window required raising; that interval is not a cold-load timing result.
The run passes its scene-lifetime/memory guards on this Apple M5 Pro, separate
from minimum hardware, continuous worst-track, GPU-memory or thermal acceptance.
The source/art identities remain unchanged. Official region hosting is now
explicitly owner-deferred; the two shipped official URLs remain blank.

## Installation, published artifacts and trial reachability

The exact public **Build 94** macOS ZIP/APK and their metadata match every
downloaded checksum line. Both actual published artifacts complete six ordinary
seven-opponent Quick Race captures, each at tick 1,200: twelve total, separate
from the earlier clean local exports. Installing the public APK over the same
version preserves all **32** existing files, UID and verified signer; equality
requires an explicit helper option. [Provenance/captures](evidence/published94/)
and [original-pace footage](evidence/published94/footage/) retain the distinction.

Clean local **Build 95** (`9d50b49`, gameplay `4eaef43b…`, cosmetic `442367da…`)
passes actual offline install and uninstall/reinstall in the new
`pacific_rush_install_95` Android 15 ARM64 AVD. The native bridge reports no
default route. Native save/key cold reads succeed before uninstall; the app
directory and old save/key/alias are absent afterward, and reinstall shows fresh
preferences. The eight-step KeyStore absence/tamper/replacement/erase sequence
also passes. [Installation runbook/evidence](INSTALLATION.md) records ownership
guards and reviewed renders; older phone/tablet data stays outside this fixture.

The tablet's actual Build 95 APK separately finishes an eight-human race/rematch
at **150% UI scale**. All **16 finishes** match complete authority/native rows
and Android parsed-row hashes, preserve all eight identities and commit exactly
two Android results. The eighth-place local row remains visible in the reviewed
results render. [Tablet report and renders](evidence/install95/tablet-crossplay.json)
retain its real emulator/automated-input boundary.

All **24 car/course standing-start Time Trials** reach the existing Gold targets
with valid finishes and zero recoveries through ordinary shared-controller input
frames. Actual times span **47.908–69.524 seconds**; the tightest observed margin
is **22.025 seconds**. No medal threshold or car rule changes. The new required
source gate retains each input-stream hash and [raw case evidence](evidence/content5/TRIAL_GOLD.md).
Human difficulty balance remains open.

Remote **Build 95 is blocked**, with no release: its source fixture uses an
engine-delta timer to check the worker's monotonic 15-second supervisor lease.
That test now polls the same monotonic clock with an independent 20-second bound.
Retirement is also idempotent across repeated 401/404 and drain callbacks;
late success cannot reopen it. Local actual lease observations are
**15.004/15.002 seconds**. [Failed CI log](evidence/content5/ci95-source-failure.log)
is preserved. A separate local source run found an uptime-named ghost-test folder
colliding with an old synthetic .1-second record. Fifteen test folders now use
random UUIDs; old bytes and the failed report remain under
[validation evidence](evidence/validation96/). The corrected **91-command source
matrix passes**, including all 24 Gold cases and the actual 15-second lease.
The actual supervisor lifecycle follow-up is running at this checkpoint.
