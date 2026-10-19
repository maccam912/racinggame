# Implementation status

The design remains the complete launch contract. Milestone work is sequential; blocked physical-device validation is recorded separately from source implementation.

## M0 — toolchain and contracts

- Godot 4.6.3 Standard, Compatibility renderer, GodotPhysics3D, 60 Hz.
- Four car definitions, six canonical 2 m route bakes, AI target-speed lines, ordered gates, safe recovery poses, versioned rules.
- Route length/radius/grade/start-region and nonadjacent-section checks pass in the canonical Python bake.
- Minimal client and headless UDP worker startup; Linux/Windows/macOS-universal/Android ARM64/server export presets.
- GitHub Actions validates bakes and shared resources, exports all platforms, and publishes a numbered prerelease on each main push.

Local macOS universal, release-mode Android ARM64 APK and development-signed AAB exports succeed. The exported macOS package passes native headless startup, and two native graphical clients render the 3D race. A disposable Pixel 7 profile / Android 15 ARM64 emulator installs and renders the APK; landscape-only orientation was corrected from that check. No physical Android device is attached. Caddy is pinned by image digest and SQLite driver version is selected; the directory service and both hosted regions are not yet implemented/deployed.

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
- Raw ENet channels: reliable session/results, 30 Hz redundant six-frame inputs, 20 Hz snapshots, 2 Hz clock probes. Full eight-car snapshot is **575 bytes**, input batch **82 bytes**.
- Quantized prediction, 180-tick input history, authoritative restore/replay, separate 0.12 s visual correction half-life, 100 ms remote interpolation and capped 150 ms extrapolation.
- Missing-input neutralization, uint32 sequence wrap, malformed/overflow rejection, eight-seat cap, 20-second reconnect reservation and bot takeover.
- Direct Connect validates host/port (including bracketed IPv6) and labels the community server. M2 worker auto-starts when two clients load; full ready/lobby flow remains M3.
- Real UDP proxy tests impair ENet handshakes, ACKs and reliable packets as well as racing datagrams: **75 ms delay per direction, ±30 ms jitter per direction, 3% random loss**. Added round-trip delay is 150 ms; observed RTT also includes frame/poll scheduling.
- Complete Palm Bay race plus five-second disconnect/reconnect: original slot retained; both clients receive exactly equal server standings/finish times; moving clear-road samples 1,147/1,288, p95 corrections 0.0101/0.0098 m.
- 340-second alternating side/rear fixture: **84 distinct contact episodes**, 1,075/1,224 contact correction samples, p95 **0.906/0.826 m** (limit 1.5 m). Reset transitions are explicitly tagged/excluded; moving clear-road p95 remains below 0.01 m. See [contact evidence](evidence/m2-udp-contact.json) and [race/reconnect evidence](evidence/m2-udp-race-reconnect.json).
- Source contracts/numeric/scene/race/contact/jump suites pass. CI now gates publishing on these suites, faulted network runs, six exports, and native package startup on Linux, Windows, macOS ARM64/Intel and Linux server.

Pending M2 gates: Android/desktop cross-play evidence, physical-device network tests, 25-second disconnect expiry, eight-client/security fault matrix and broader correction/performance soak. Official ticket-required directory workers are M3 work; current tested service mode is explicitly community/direct-guest.

## Next

M3: complete mode/menu flow, bots, persistent lobbies, directory APIs, settings, records, ghosts and cup saves. M4–M6 remain unimplemented. Physical M0/M1/M2 gates stay open while source implementation continues; no physical-mobile acceptance is claimed.
