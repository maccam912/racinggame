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
All nine shipped spatial shaders are covered across eight courses, including
the procedural Skyline facade material. Current inventory reaches at most
61 submissions. Instanced effects use the same material
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


The graphical fixture separates construction from GPU readiness. Construction
allows `max(60000, (world.build_steps() + 4) * 1000)` milliseconds; the GPU stage
retains 15,000 milliseconds. Actual authored work determines the allowance:
Skyline has 70 construction units / 74 seconds, Quarry 90 / 94. Native slow
probes use `--slow-construction-probe` (Citrus, 3 fps) and
`--slow-long-construction-probe` (Quarry, 1 fps), restoring the original frame
cap before GPU preparation. These are fixture bounds, not normal loading-time
or minimum-hardware performance promises.

The JSON report clears previous success at startup and stores a unique run ID,
fixture SHA-256, current content/cosmetic identity, each completed course and
its measured duration/allowance. A timeout retains the failed stage and loader
state. Only the completed full matrix sets `passed=true`. Historical failures,
slow native probes and Linux follow-up are preserved in
[the graphics evidence](evidence/graphics108/).
