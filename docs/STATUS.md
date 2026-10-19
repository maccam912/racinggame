# Implementation status

The design remains the complete launch contract. Milestone work is sequential; blocked physical-device validation is recorded separately from source implementation.

## M0 — toolchain and contracts

- Godot 4.6.3 Standard, Compatibility renderer, GodotPhysics3D, 60 Hz.
- Four car definitions, six canonical 2 m route bakes, AI target-speed lines, ordered gates, safe recovery poses, versioned rules.
- Route length/radius/grade/start-region and nonadjacent-section checks pass in the canonical Python bake.
- Minimal client and headless UDP worker startup; Linux/Windows/macOS-universal/Android ARM64/server export presets.
- GitHub Actions validates bakes and shared resources, exports all platforms, and publishes a numbered prerelease on each main push.

Pending M0 evidence: actual exported package starts, native mesh/collision validation, physical phone render/input. Directory driver/proxy pins will be filled when the service is introduced. No directory or hosted region is deployed.

## Next

M1: pure shared vehicle simulation, Palm Bay graybox mesh/collision, keyboard/gamepad/touch, camera/recovery, numeric fixtures and desktop driving captures. Then M2: dedicated authority, prediction, progress/contact/reconnect and network fault fixtures. M3–M6 remain unimplemented.
