# Original scenery detail

The original Blender generator now builds paired uneven mountain ridges and
shelved sandstone buttes. They use closed meshes, explicit three-level LODs and
the existing shared material. Summit peaks are at most 55 m high and remain
inside their 52 m horizontal placement envelope; canyon rocks are at most 24 m
high inside 25 m. Conservative per-vertex checks cover every LOD. Placement adds
a small deterministic yaw variation without changing collision or route geometry.

| Model | LOD 0 | LOD 1 | LOD 2 |
| --- | ---: | ---: | ---: |
| Sandstone rock | 224 triangles | 120 | 44 |
| Summit paired ridge | 216 triangles | 120 | 58 |

Original mathematical grain adds restrained strata, stone veins and wood grain
inside the existing palette cells. The 1024² scenery and 512² prop atlases retain
mipmaps. This code-authored texture work does not modify the generated foliage
or travel-poster images.

All 47 GLBs retain UVs and their single primitive per LOD while exporting
placeholder material slots instead of embedding atlas images. Runtime assigns
the shared atlas, as before. Validation rejects duplicate embedded images and
checks all explicit triangle counts. Geometry files total **3,072,752 bytes**,
down from **3,929,256 bytes** at the preceding sign checkpoint, despite the more
detailed rocks. This measures source geometry file sizes, not runtime memory.
The editable `.blend` retains packed authoring textures.

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python assets/source/generate_scenery.py
python3 tools/asset_hash.py
python3 tools/godot.py --headless --editor --import --quit
python3 tools/godot.py --headless --script tests/scenery_contract_tests.gd
python3 tools/godot.py --max-fps 60 --script tests/scenery_library_evidence.gd
python3 tools/godot.py --max-fps 60 --script tests/roadside_poster_tests.gd
```

The initial Blender-detail checkpoint's [native library and road-approach views](evidence/scenery-detail/) show all
three LODs and the actual Canyon/Summit scenery. They are posed renderer checks,
separate from normal-race exported desktop/Android captures. Gameplay content 5,
protocol 5 and save schema 1 remain unchanged. Cosmetic identity is
`442367da36de66721bbb1ac5b6f666880ab372f9ede98afa1be8573399ecbb74`.


Current procedural roadside detail extends those unchanged 47 GLBs with bounded
3D boulder clusters, cut-log piles, quarry bluffs and Skyline towers. Illustrated
waterfalls retain 3D base rocks and animated pools. Clearance plans reserve road
and poster sightlines; each root has independent bounds and distance culling,
without new driving collision. Both roadside instances are checked by semantic
metadata even if Godot auto-renames duplicate node names.

Skyline facade walls add original metre-aligned panes, static glass sweeps,
warm rooms, ordered dither and derivative-filtered distance detail. Trim and
roof equipment remain opaque solids. Existing tower geometry and default atlas
shading are preserved. [Current source/native evidence](evidence/city108/)
records the current identities, source checks and exported follow-up; the
initial material/content-5 identity above describes its original checkpoint.

## Content 9 waterworks and volcanic scenery

`game/world/course_spectacles.gd` authors batched concrete dam arches/cascades, bounded basalt formations, a multi-ring crater with cosmetic lava, and sixteen distant cliff/ridge silhouettes per new route. The entire 300 m crater footprint and every roadside footprint stay clear of all crossing branches. Planned clearings reserve vegetation space before scenery batches are built. These meshes have no driving-collision bodies.

The original waterfall cutout retains scale under tall dam openings; painted falls and animated pool materials are shared within the new world. Default original-course waterfalls retain unit scale. Fine strata/grain in the original landscape shader fade with derivatives and use static ordered dither; distant cliff meshes contain few triangles and remain visible for the skyline. All eight existing route definitions/bakes and their terrain bytes are preserved.

The two new terrain exports use a 1,000 m route margin (506/552 chunks) to support the distant silhouettes. Original eight terrain descriptors/bytes remain exact. Formation bases embed below the mesh, and a two-triangle floor below the authored terrain remains visible when detailed chunks cull. A regression checks actual underlying terrain beneath every distant-cliff vertex.
