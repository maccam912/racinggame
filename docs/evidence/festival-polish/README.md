# Festival fairground refinement

The existing fairground footprints now contain saturated striped fabric, opaque
emissive bulbs, pennants and three spectators per tent. A pre-existing back-face
culling defect made one roof slope and flags disappear; fabric now has front and
back faces. No scenery locations, terrain or road geometry change.

Native macOS Compatibility captures show actual models and an ordinary road
approach. Source compilation, district mesh budgets/normals/roof coverage and all
40-course authored composition clearances pass (three focused commands). Models
stay under 850 triangles each, use existing materials and distance culling, and
add no dynamic lights, collisions or animation callbacks. Physical-device frame
timing remains unmeasured. Reproduce native captures with
`tests/festival_detail_evidence.gd`.
