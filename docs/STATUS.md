# Implementation status

The design remains the complete launch contract. Milestone work is sequential; blocked physical-device validation is recorded separately from source implementation.

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

Pending M1 gates: physical phone driving, human cornering/feel playtest, complete behavioral reference videos and all camera-collision edge cases. Recovery fades/ghost opacity and final visuals remain M4 work. Visuals are an explicitly labeled development graybox.

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
- Desktop/mobile settings are separate. The tabs expose the specified value rows; working preferences include units, camera/FOV/motion, input deadzone/sensitivity/auto acceleration, UI scale/contrast, frame cap, MSAA/render scale, brightness/shadows and master volume. Display changes have a 15-second Keep/Revert flow. Per-channel audio, remapping, touch-layout editing and adaptive quality are still pending.
- Bundled Barlow fonts/OFL licenses and external English text catalog. Display names normalize to NFC with vendored Unicode 16 tables and enforce grapheme/UTF-8/control/markup limits.
- Automated menu navigation, real scene pause/resume, save/ghost/cup/name/mode fixtures pass. Native macOS screenshots were reviewed at 100%/150% UI scale and 4:3; a footer overflow was corrected. These checks do not establish Android menu usability or final art quality.

Content version is **2**, and protocol version is **4** for lobby/loading/rematch and compact racing control events. Recovery/progress state required by reconciliation is versioned. M2 clients and their records/cups are intentionally not silently mixed with this version. Snapshot decoding validates the added lap and distance fields; the eight-car payload remains below 1200 bytes.

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

Finish M3: directory/ticket APIs, remaining input/settings behavior and broader end-to-end mode checks. M4–M6 remain unimplemented. Physical M0/M1/M2 gates stay open while source implementation continues; no physical-mobile acceptance is claimed.


Linux reconnect follow-up: held/neutral server ticks can advance the car without advancing its input acknowledgement. Replaying every unacknowledged frame then duplicated elapsed time, especially when several snapshots arrived together. Reconciliation now uses the snapshot tick and fixed input buffer to bound replay, preserves old frames for redundant transmission, uses monotonic intended ticks, and rejects snapshots until welcome completes. A regression fixture verifies an unchanged-ack pair of snapshots preserves the same predicted endpoint. The local forced-right-lane fault run has moving clear-road p95 0.0183 m; subsequent Linux probes measure 0.0187/0.0191 m. Those probes also exposed stale transport mirrors after forced ENet removal. Forced removal now clears the mirror and queued sends exactly once; a clean local replay measures 0.0211 m p95 with no engine errors. Build 10 subsequently passed the full Linux fault/rematch gates, all exports and native platform startup checks, and was published.


Directory authentication foundation (not yet connected to game menus): Go 1.27 / SQLite guest registration, AES-GCM secret storage, one-use 60-second HMAC challenges, one-hour bearer sessions, five/hour name changes, strict HTTPS/proxy boundaries, bounded JSON, IP rate limits and RSA-2048 admission primitives pass real SQLite/TLS and race-detector tests. Unicode 16 normalization is shared with Godot and grapheme segmentation is pinned. Room allocation, worker admission and Caddy integration are covered by the later checkpoint below. Native client secure storage, client directory menus and public deployment remain pending.

Follow-up contracts to finish before launch: add a clock rebase path for a client hitch that loses more physics ticks than the accepted input window; complete touch/manual throttle, input ownership/remapping and display-dialog lifecycle behavior. These are explicit remaining implementation tasks, not established acceptance results.

Directory room API checkpoint: authenticated create/join/code/leave, public compatible-room browsing, eight-seat union reservations, 15-second holds, 60-second signed tickets, stale-worker hiding and bounded readiness are implemented. A separate credential-protected private HTTP handler accepts worker heartbeat/admission consumption and idempotent leave commands. Real SQLite/TLS tests cover concurrent final-seat joins, expiry/replay, private visibility, rate windows, migration and listener isolation; Go race detector and vet pass. A process supervisor, worker integration, native secure storage, client directory menus and deployment remain pending.

Managed-worker checkpoint: the Go service launches an operator-configured, bounded headless process pool outside database transactions and reaps exited children before reusing their ports. Godot `ticket_required` workers verify Go RSA signatures, compatibility, exact expiry and one-use nonces, then confirm reservations through their private credential-protected interface before spawning. Client packets cannot downgrade this mode; direct-guest workers remain separately configured. Official guest UUIDs survive authoritative race results.

Eight independent clients using Go-issued admissions completed Palm Bay and Citrus Pass in the same allocated room, with equal final rows on all clients. A ninth reservation returned 409; live missing/forged/duplicate-ticket probes were denied. See [directory-backed rematch evidence](evidence/m3-directory-eight.json). Cross-language fixture checks cover signed invalid claims, wrong room/worker, exact expiry and packet budget. A real child-process test proves the allocation request ending does not kill its room, pool caps hold, and root cancellation reaps workers.

Pinned Caddy 2.11.7 runs a separate HTTPS/proxy fixture using an isolated test CA without modifying system trust. Real registration/NFC-HMAC auth, nonce replay rejection, direct HTTP denial, private-route isolation and forwarding-header rate-limit boundaries pass; operational logs contain no test credentials. See [HTTPS evidence](evidence/m3-caddy.json). Production logs use fixed structured events, UTC daily rotation, a 100 MiB daily ceiling and seven-day retention. Caddy configuration and local operator CLI are included; public hosting, production certificates, secure client identity adapters and killed-supervisor adoption remain separate work. CI now gates releases on these service/engine integration tests too.

Protocol 4 traffic checkpoint: active-race lobby changes/heartbeats use bounded presence rows, and reconnects use compact IDs/car/paint rows with names resolved from the already received roster. Unknown human names fail reconnect safely; loading exclusions may resolve only shipped bot callsigns. A send guard rejects large reliable events while the worker is racing. Full names/rosters remain available during loading and results, outside active racing. This is a protocol/hash compatibility change; gameplay content remains version 2.

The Godot source suites and Go race-detector suites pass. The first protocol-4 CI run caught a stale protocol-3 JSON schema pin; that schema was corrected before subsequent release checks. An impaired two-client reconnect preserves its slot and exact final results, with p95 moving corrections 0.0199/0.0164 m and zero large racing roster events; see [protocol 4 reconnect evidence](evidence/m3-compact-reconnect.json). The eight-client directory fixture now also disconnects one client for five seconds, restores the same official identity through compact resume, and completes both races with identical rows and zero large racing events. Live missing/forged/reused-ticket probes and Caddy HTTPS boundaries still pass. Ordinary worker stdout reports result counts only; full result-row console output requires an explicit evidence flag.
