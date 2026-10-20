# Original car detail and road-visible Caldera channels

Cosmetic follow-up to clean content-9 Build 110. Four original cars retain their
silhouettes, authoring dimensions, shared atlas, five mesh parts per active LOD
and unchanged distant LODs. Painted window pillars, glass seals, paired wipers,
rear defroster lines, lamp segmentation, rear fascias and plate recesses add
near/middle detail. Needle adds original deck vents; Sunset has a chrome bumper.
The editable Blender source and generator remain under the project MIT license.
No generated bitmap or external model was added.

The native before/prototype comparison retains exact GLB/shader digests. Final
integrated models pass all 240 actual body-attachment rays and all explicit LOD
budgets/roles/animation rules. Original failed Switch rear/FOV55 hood framing is
preserved under `initial-hood-near-clip/`: the new defroster edge was inside the
near clipping plane but still influenced the contour calculation. Camera framing
now ignores contour candidates clipped at the intended framing position. All
40 actual native front/rear/FOV cases measure 10% bonnet after correction; the
fixture now also saves a targeted PNG for any future failed raster case.

Caldera's three irregular molten channels follow its real exterior slopes, stay
inside the existing 300 m road-clear clearing and share the existing pool
material/shader. All **216 actual channel faces** hit the underlying cone within
6 m, and **360 road-view/face pairs** have unobstructed line of sight against
that cone. These are cosmetic geometry only, with no driving collision.
Diagnostic overviews explicitly override scenery culling for inspection; they
are not ordinary gameplay or production draw-distance evidence.

The paired asset hash is `d817e6717c7a87d4513b55d029bed7f32825c1f190d1384a79aa53c93d5df75f`.
Gameplay/protocol/save remain **9/5/1**, gameplay digest `f762fa68`; route bakes,
handling, records/ghost compatibility and the six-event Cup remain unchanged.
Native checks pass all 40 course reference views and all ten actual GPU-prepared
worlds, maximum 61 submissions, two drawn frames/readback and the independent
15-second GPU deadline, with Retry/Cancel/background/real-ENet Loaded cases.
All **101 final source commands** pass after the camera correction and final
channel silhouette. `source101-final/` retains every command/log, separately
from the earlier passing source suite and the failed native raster case. Clean
packages and remote publication remain pending at this source checkpoint. Build 110's passing 15-minute lifetime run retains its
own earlier exact asset identity `1fe44b97`; it is not relabeled as these assets.
