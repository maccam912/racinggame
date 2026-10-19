# Implementation status

The design remains the complete launch contract. Milestone work is sequential; blocked physical-device validation is recorded separately from source implementation.

## M0 — toolchain and contracts

- Godot 4.6.3 Standard, Compatibility renderer, GodotPhysics3D, 60 Hz.
- Four car definitions, six canonical 2 m route bakes, AI target-speed lines, ordered gates, safe recovery poses, versioned rules.
- Route length/radius/grade/start-region and nonadjacent-section checks pass in the canonical Python bake.
- Minimal client and headless UDP worker startup; Linux/Windows/macOS-universal/Android ARM64/server export presets.
- GitHub Actions validates bakes and shared resources, exports all platforms, and publishes a numbered prerelease on each main push.

Local macOS universal and Android ARM64 exports succeed. A native macOS Compatibility-renderer capture shows the graybox road/car/HUD. Physical phone render/input remains pending: no Android device is attached. Directory driver/proxy pins will be filled when the service is introduced. No directory or hosted region is deployed.

## M1 — driving slice

- Pure shared 60 Hz controller: steering/yaw filters, ground support, acceleration/braking/reverse, drift/grip recovery, surface grip/drag, gravity and landing.
- Palm Bay graybox road and continuous barrier collision from the canonical bake, original editable procedural Comet, palms, sea, gantry and road furniture.
- Near/Far/Hood cameras, look-back, dynamic vertical FOV and Reduce Motion.
- Keyboard, analog gamepad and independent multitouch slider/brake/handbrake/recovery; offline pause with three-second resume safety countdown.
- Ordered swept gates, sub-tick finish, lap count, wrong-way detection and last-valid-gate recovery with fade/ghost state.
- Numeric tests: Comet 0–100 km/h **2.300 s**, 100–0 **20.806 m**; drift restores grip in 0.40 s; repeated 60-second fixture agrees within 2 cm.
- Engine collision fixture: 109 sustained scrape contacts; first tangential speed 37.058 m/s, final 33.458 m/s; no wall penetration beyond 5 cm. Five-pointer touch ownership/cancellation and skipped/reverse gate fixtures pass.
- Headless full-scene smoke verifies real action input moves the car on baked collision and pause/resume freezes position/timer correctly.

Pending M1 gates: physical phone driving, human cornering/feel playtest, complete behavioral reference videos, jump fixture and all camera-collision edge cases. Visuals are an explicitly labeled development graybox; final assets remain M4 work.

## Next

M2: dedicated authority, prediction, progress/contact/reconnect and network fault fixtures. M3–M6 remain unimplemented. Physical M0/M1 gates stay open while source implementation continues; no mobile acceptance is claimed.
