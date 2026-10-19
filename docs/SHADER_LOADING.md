# Graphics preparation during Loading

`TrackLoader` constructs the actual selected track while detached, then renders
material variants in a private 256×256 `SubViewport`. Only after two foreground
draws and a successful GPU image readback can loading complete. The viewport
uses the selected MSAA, anisotropy, brightness and shadow setting. It has its own
3D world, no input, no audio listener and no collision bodies. The real course
never moves into this temporary world.

Submissions include actual imported mesh formats, ordinary and instanced track
materials, all four car models and LOD formats, normal/fading/ghost car shaders,
slot-number glyphs, blob shadows, smoke/dust/sparks and skid batches. Materials
are collected from the selected course; water is required only on water courses.
All eight shipped spatial shaders are covered across the six courses. Current
inventory is bounded at 38–46 submissions. Instanced effects use the same material
factories and instance-color layout as gameplay. Model/material resources remain
owned by the prepared course after temporary submissions are freed.

The final progress unit is reserved for graphics. Background suspends this unit
and resets its consecutive-frame count. An unsuccessful readback shows Retry
and Cancel while retaining the built, detached course. Retry reconstructs only
the graphics stage. Cancel frees both worlds and guards completion against stale
callbacks. Neither path advances simulation, commits statistics or sends Loaded.
Online preparation sends Loaded only after this stage and the existing physics
registration frame; disconnected readiness continues to use the established
reservation protocol. Headless fixtures explicitly record `gpu_warmed=false`
and never present source-only checks as rendering evidence.

Run the source inventory with:

```sh
python3 tools/godot.py --headless --script tests/shader_warmup_tests.gd
python3 tools/godot.py --max-fps 60 --script tests/shader_warmup_evidence.gd -- --profile=shader_warmup_reference --capture=res://reports/unused-warmup.png
```

The native fixture renders every course with disabled/2×/4× MSAA, checks actual
visible-object/draw counts and 256×256 readback, freezes before Grid tick zero,
and exercises background waiting, injected failure, the real Retry action,
Cancel and an actual ENet Loaded boundary. Linux CI runs it with a software
Compatibility context and uploads its images and JSON. Android validation uses
the exported APK's real loader against a separate local authority; successful
loads print numeric `PACIFIC_RUSH_GRAPHICS_PREPARED` diagnostics before driving.

This warms known gameplay variants. The evidence does not establish universal
driver cache behavior, absence of every future graphics stall, first-install
performance on all hardware, or physical-device thermal acceptance. In-race
settings changes can select a new renderer variant. Godot's renderer remains
responsible for driver program caching; see its [viewport rendering API](https://docs.godotengine.org/en/4.6/classes/class_renderingserver.html).
