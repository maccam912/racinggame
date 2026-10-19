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
