# Illustrated foliage and arcade camera

The owner approved a hybrid billboard look with more decoration detail. Repeated
palms, citrus trees, redwoods, sage shrubs and grass now use original illustrated transparent PNGs;
cars, barriers, buildings and major landmarks retain 3D geometry. The previous
Blender foliage models remain editable source and are still used where explicitly
instantiated. No new driving collision comes from this artwork.

Five frozen image-generation outputs live under `assets/source/billboards`, with
generator/direction/subject provenance and SHA-256 hashes. They are original
project artwork distributed with the project's MIT license. The selected source
PNGs are copied byte-for-byte into the exported asset folder. Reauthoring the
catalog does not call a remote model or promise deterministic regeneration of a
new AI image:

```sh
python3 tools/godot.py --headless --script assets/source/describe_billboards.gd
python3 tools/godot.py --headless --editor --import --quit
python3 tools/asset_hash.py
python3 tools/godot.py --max-fps 60 --script tests/billboard_tests.gd
```

The descriptor finds exact alpha ≥128 bounds without painting/resampling the
source. Runtime UVs select those bounds, anchoring the trunk at its original
ground pose. A two-triangle card uses fixed-Y billboarding, original world sizes
and per-instance scale, alpha scissor .5, nonrepeating mipmapped anisotropic
sampling and baked painted lighting; Marina gets a cooler dusk tint. Small
stationary soft footprints anchor nearby trees. Full rotation-invariant bounds
cover the rendered card at every approach angle. Track draw distance still
applies; road/sign/collision geometry remains independent.

The Near camera moves to 5.0 m behind / 1.65 m above road. Speed adds up to 18°
vertical FOV over 15–70 m/s, smoothed at 6/s and capped at 95°. Reduce Motion and
Dynamic FOV Off preserve their existing controls. Trees move nearer the roadside,
with 16 m palm spacing, to strengthen near-field motion. Handling, authority,
route topology and saved content compatibility remain unchanged by this step.
The owner's requested handling/elevation revision is the next versioned step.

The source fixture checks alpha/hash/mipmap provenance, instancing, conservative
bounds and absent collision. The actual native rendering fixture compares each
species from four approach directions; alpha-covered area must remain within
2.5%. Dummy headless rendering has no readable GPU instance buffer, so native
readback stays a separate required CI/software-GL gate.

Engine references: [fixed-Y billboard material](https://docs.godotengine.org/en/4.6/classes/class_basematerial3d.html#class-basematerial3d-property-billboard-mode),
[MultiMesh visibility bounds](https://docs.godotengine.org/en/4.6/classes/class_multimesh.html#class-multimesh-property-custom-aabb).
