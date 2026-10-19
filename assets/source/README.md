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

The postcard command renders six 512×288 images from the original scenes; ordinary reference/CI runs do not replace shipped postcards. Historical M1 videos use frozen `GrayboxTrackWorld` and `GrayboxCarVisual` source fixtures, so regenerating them keeps the pre-art composition.

`generate_audio.py` is the editable source for all 48 original Vorbis assets. It
contains the seven compositions, arrangement, additive/FM/plucked instruments,
seeded synthetic percussion, four engine harmonic profiles, effects and eight
fixed formant/noise annunciations. No speaker recording, trained voice model,
downloaded song or sample bank is used. The formant implementation is original;
Klatt's 1980 paper (doi:10.1121/1.383940) informed the general synthesis concept.
The checked-in audio and source use the project's MIT license.

Authoring requires Python 3.14.7, NumPy 2.5.2, ffmpeg 9.0.1 and oggenc 1.4.3 /
libvorbis 1.3.7. Ordinary game builds require none of these audio authoring tools.
Run `python3 assets/source/generate_audio.py` (or `--only music`, `engines`,
`effects`, `voice`), reimport in Godot and run `python3 tools/asset_hash.py`.
Preserve the checked-in Ogg import flags: music, engines and surface loops loop
from zero; music includes exact BPM/beat/bar counts. Gain is fixed per asset from
R128 integrated loudness and oversampled true peak, with peak-only normalization
for transients shorter than the R128 gate. Circular synthesis/delay tails preserve
music loop boundaries. The catalog records duration, loudness, true peak and SHA256.

`python3 tools/audio_acceptance.py --capture` captures actual Godot decoding and
bus DSP with all seven music streams, eight four-layer engines, eight simultaneous
impacts, voice, Night and channel mute. Add `--native-output` for a rendered
Movie Maker capture after the Master fader and a final Master-mute check. It
requires ffmpeg for true-peak measurement;
the resulting WAV/report are validation artifacts, not shipped assets. This proves
the numerical mix boundary, not human listening quality or physical speaker output.
