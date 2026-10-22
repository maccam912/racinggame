# Original assets

`pacific_cars.blend` is the editable Blender 5.1.2 source for Comet, Needle, Switch and Sunset. It includes three explicit LODs per car, atlas UVs, original geometry and packed texture. Authoring uses X right, +Y nose and Z up; glTF exports convert the nose to Godot -Z. The models use the project's MIT license.

To regenerate from the original procedural authoring source:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python assets/source/generate_cars.py
python3 tools/asset_hash.py
python3 tools/godot.py --headless --editor --import --quit
python3 tools/check.py
python3 tools/godot.py --max-fps 60 --script tests/car_asset_evidence.gd -- --ci --game-ui --profile=asset_review
```

Use the equivalent Blender executable on other platforms. Blender is needed only for authoring; builds use the checked-in glTF exports. `assets/exported/cars/inventory.json` records dimensions, triangle counts, source, license and checksums. Each active LOD has five mesh parts: body plus four independently animated wheels. LOD distances are 35/90 meters. The shared atlas is 1024² with mipmaps. Godot discards embedded glTF textures and uses the one external atlas. Do not enable automatic mesh LOD generation over these explicit groups.

The `PacificRoles` vertex color channel marks paint, stripe, brake light and roughness roles. Body/stripe masks let the same imported geometry use all eight fixed paints. The separate ghost shader uses the same geometry and a 35% alpha tint. Car presentation is independent of collision and gameplay hashing. `assets/checksums.json` and exported `build.json.asset_hash` identify cosmetic content separately.

Near and middle car LODs include fitted painted A/B/C pillars, rubber glass
seals, paired windscreen wipers, rear defroster lines, lamp trim and rear fascias
with plate recesses. Needle has original rear-deck vents; Sunset retains a
chrome bumper treatment. The four silhouettes, authoring dimensions, shared
atlas and distant LODs remain unchanged. These are original model geometry,
combined into the same five mesh parts per active LOD; no extra texture or
runtime draw part is introduced.

The source directory is ignored by Godot import so opening/building the game does not invoke Blender. Keep `.gdignore`. Generated authoring backup files are not release inputs.

`pacific_scenery.blend` contains the 30 named landmarks plus five vegetation models, seven roadside props, three shared buildings and two landscape forms. `generate_scenery.py` creates the geometry, original atlases and explicit LODs. Landmark/building LODs are rebuilt with fewer structural segments and without lettering/trim; distant versions preserve their main shapes. Vegetation uses small meshes through 180 m, then grouped crossed silhouette cards from the original foliage atlas. Every model has one material surface per LOD, and batches share its mesh/material.

`course_specs.json` records the design's original curve-u anchors and six lighting presets. `generate_terrain.py` reads the existing canonical bakes and creates cosmetic 160 m terrain chunks; it records each source route hash. Neither terrain nor landmarks supply driving collision. Camera bounds use a separate layer. The shared road kit is editable code in `game/world/course_road_mesh.gd` and `track_world.gd`; it extrudes the unchanged barrier planes, places guidance, start lamps and tunnel panels, and adds Summit's painted jump bars.

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python assets/source/generate_scenery.py
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python assets/source/generate_terrain.py
python3 tools/godot.py --headless --editor --import --quit
python3 tools/godot.py --max-fps 60 --script tests/course_reference_evidence.gd -- --ci --write-thumbnails
python3 tools/asset_hash.py
python3 tools/check.py
python3 tools/godot.py --max-fps 60 --script tests/scenery_library_evidence.gd
```

The postcard command renders forty 512×288 images from the original scenes; ordinary reference/CI runs do not replace shipped postcards. Historical M1 videos use frozen `GrayboxTrackWorld` and `GrayboxCarVisual` source fixtures, so regenerating them keeps the pre-art composition.

`generate_audio.py` authors the four engine profiles, filtered-noise tire scrub,
effects and fixed formant/noise annunciations under MIT. The seven music streams
are human-authored rock/metal recordings imported by `import_cc0_music.py` under
CC0; the original recordings, creator pages and license evidence live in
`music/`, with packaged attribution in `assets/licenses/CC0-Music.txt`.

Authoring requires Python 3.14.7, NumPy 2.5.2, ffmpeg 9.0.1 and oggenc 1.4.3 /
libvorbis 1.3.7. Ordinary builds require none of these authoring tools. Run
`python3 assets/source/generate_audio.py --only skid` for tire scrub, or
`--only engines`, `effects`, `voice`. Run `python3 assets/source/import_cc0_music.py`
to rebuild recorded music from the retained originals; `--download` is only for
initial sourcing. Music processing applies a 25 ms circular seam, R128 gain
normalization and Vorbis encoding, preserving tempo and arrangement. BPM/beat/bar
metadata is zero because these recordings are not generated metronomic loops.
Reimport in Godot and run `python3 tools/asset_hash.py`. Preserve loop flags for
music/engines/surfaces. The catalog records source/license, duration, loudness,
true peak and SHA256.

`python3 tools/audio_acceptance.py --capture` captures actual Godot decoding and
bus DSP with all seven music streams, eight four-layer engines, eight simultaneous
impacts, voice, Night and channel mute. Add `--native-output` for a rendered
Movie Maker capture after the Master fader and a final Master-mute check. It
requires ffmpeg for true-peak measurement;
the resulting WAV/report are validation artifacts, not shipped assets. This proves
the numerical mix boundary, not human listening quality or physical speaker output.

Driving feedback uses code-native geometry/materials in `game/world/race_feedback.gd`
(and original `feedback_particle`, `feedback_skid` and `car_fade` shaders). The four
shared batches contain no bitmap assets or collision. Budgets, lifetime, strip
recycling and Reduced/Off behavior follow DESIGN §12.3. Transparent warm geometry
is submitted during the initial Grid frames, sharing the active world. Run
`tests/feedback_render_evidence.gd` with an actual renderer for ten effect/recovery
views; headless numerical tests do not establish shader compilation. Recovery
covers the world while relocating the chase camera and preserves the existing
simulation freeze/ghost timers.

`generate_icons.py` creates the 94 original 64×64 SVG interface assets and catalog
using only Python's standard library. Course outlines come from the canonical
baked routes, and swatches use the actual eight car paints. No external icon
set is used. Regenerate with `python3 assets/source/generate_icons.py`, preserve
the mipmapped SVG import settings, reimport and run `python3 tools/asset_hash.py`.
`tests/interface_icon_evidence.gd` renders the library plus selection, medal,
trophy, settings and results views. Synthetic records/trophies in that isolated
fixture demonstrate presentation only.

Application branding uses `generate_app_icons.gd` for the original coupe/sunrise
vectors, lossless desktop/store/adaptive PNGs, Windows ICO and macOS Retina
iconset. Run `python3 tools/app_icons.py --generate` on macOS with the pinned
engine and native iconutil, then update `tools/asset_hash.py`. The committed
native containers and all safe-mask/package checks are described in
[application icons](../../docs/APP_ICONS.md).

The owner's illustrated billboard revision preserves the original 3D foliage models
but uses five frozen, original image-generation PNGs for repeated palm/orchard/
redwood/shrub/grass cards. `billboards/generation.json` records provenance and prompts;
`describe_billboards.gd` copies exact bytes and authors alpha-derived UV bounds.
See `docs/BILLBOARD_ART.md` for material, mipmap, visibility and native-render gates.

`game/world/waterworks_detail.gd` is the editable original waterworks machinery
kit. It adds control houses, glazing, supported platforms, pipes/clamps, bounded
ladder rungs, shaft-mounted valve wheels and truss cranes/hoists directly to the
existing dam `SurfaceTool`. Three paint/side/hoist variations use the current
landscape material. No extra texture, material, collision body or per-frame work
is introduced; complete meshes retain their 26 m footprint and 3,000-triangle
fixture ceiling. Native inspection cameras under the current evidence checkpoint
show both station and gantry details; those views override scenery culling only
for inspection.

## Original small roadside scenes

`game/world/roadside_life.gd` is editable original MIT geometry for surf huts with
closed porch ceilings and extruded board racks, striped two-sided umbrellas and
loungers, braced produce crates with 20-face oranges, and corrugated harbor cargo
stacks with doors/locking rods. `CourseDecor` selects existing Palm/Citrus/Marina
roadside sites, preserving their circular seven-metre clearance and one shared
material/surface per scene. Four paint variants, fewer than 500 triangles per
scene and no collision or frame callback. No external mesh, texture or model
input. Native details and ordinary course views remain separate visual evidence.

The `billboards/arcade-*-v1.png` files are original, unmodified built-in
image_gen outputs: six tree variants, six roadside scenery props, and a painted
90s arcade panorama. Exact prompts and checksums live in
`billboards/arcade-generation.json`. The exported billboard catalog selects
alpha-bounded atlas cells without altering source pixels. Runtime dimensions
preserve each silhouette's aspect ratio. `ArcadeSpriteVariety` mixes species by
course and lap sector and places props beyond road and poster clearances.
`painted_sky.gdshader` blends the panorama wrap and poles, with a night tint for
city courses; the orbital course keeps its dedicated sky.


## Forty-course expansion and recorded music

`tools/author_expansion40.py` contains thirty separate authored polygons and
course palettes/landmark arrangements. Run it, then `tools/bake_tracks.py`,
then Blender's `generate_terrain.py -- --tracks=<selected IDs>`. The original
ten routes and terrain bytes are retained. `expansion40/generation.json`
records the six atlas prompts and one standalone cherry-tree prompt from built-in image_gen, source/output paths and checksums.
`describe_expansion40.py` catalogs 52 alpha-bounded UV cells without editing
the PNGs. `game/world/expansion_course_art.gd` supplies static, spatially batched
roadside scenery and original 3D gates. Course reference captures author native
512×288 postcards; icons use the existing SVG generator.

Music is no longer synthesized. `import_cc0_music.py --download` obtains the
seven named CC0 recordings and source-page snapshots; subsequent rebuilds omit
`--download` and use the retained originals. `music/cc0-sources.json` records
composers, title/source/download/license URLs and exact source hashes. Processing
preserves tempo and arrangement, with a 25 ms circular seam, gain normalization
and Vorbis encoding. `generate_audio.py --only music` calls that importer.
Other generator modes preserve the recorded catalog entries. `--only skid`
rebuilds only the broadband, non-tonal tire-friction loop.
