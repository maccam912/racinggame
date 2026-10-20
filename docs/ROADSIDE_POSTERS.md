# Painted roadside travel signs

Eight original generated illustrations give the fictional courses painted travel
signs. The signs use course names and scenery already defined by the game. They
are decorative artwork on 3D frames; navigation remains the road, chevrons and
advance-warning boards.

The selected 1536×1024 PNGs and complete prompts live in
[source provenance](../assets/source/roadside-posters/generation.json). The
built-in `image_gen.imagegen` tool produced each image separately, without a CLI,
API key, external reference image or downloaded artwork. The cataloguer copies
the selected bytes unchanged into the exported folder; it does not generate,
paint, crop or resample images. New remote generations would be new versions,
not deterministic replacements for these frozen originals.

```sh
python3 assets/source/describe_roadside_posters.py
python3 tools/godot.py --headless --editor --import --quit
python3 tools/asset_hash.py
python3 tools/godot.py --max-fps 60 --script tests/roadside_poster_tests.gd
```

Committed imports generate mipmaps. Each 12×8 m panel has a static face aimed
toward approaching traffic, opaque unshaded color, back-face culling and clamped
anisotropic sampling. The 3D wooden backing and posts remain visible from behind.
There are three signs per course, with conservative clearance from every road
section. A small view corridor removes only decorative trees/shrubs that would
hide the panel, including their canopy width. Grass and driving geometry remain.
Signs participate in the existing scenery-distance setting and add no collision.

The memory-pressure path drops reusable sign materials while active scene nodes
retain their textures. Source tests check all eight raw/source hashes, opaque
pixels, mipmaps, fixed orientation, 24 clear sites and active texture ownership.
The native/software-GL CI gate renders every course's first sign from a normal
Near Chase approach. Source views were inspected after clearing initial tree
occlusion. [Native views and numeric evidence](evidence/posters/).

Cars, buildings, bridges and crest structures retain their 3D geometry.
The five illustrated foliage species still use cylindrical billboards as
described in [the foliage checkpoint](BILLBOARD_ART.md). The sign artwork has a separate cosmetic identity; current gameplay/protocol/save
versions and exported acceptance are recorded in the status report.


Skyline's elevated signs use original triangular cantilevers attached below the
bridge deck. Structural checks keep their beams outside the seven-metre driving
corridor; source/native approach and external support views are retained in
[the arcade touch/bridge checkpoint](evidence/arcade-touch106/). The original
six-sign images/evidence above remain historical; current eight-sign native
views are included in [the facade checkpoint](evidence/city108/).

Content 9 adds unmodified original Spillway Sprint and Caldera Crosscut paintings. Their complete prompts and output/source provenance are in `assets/source/roadside-posters/generation.json` and `new-courses-provenance.json`; each exports byte-for-byte at 1536×1024 with mipmaps.
