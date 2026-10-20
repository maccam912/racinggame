# Content 5: speed, hills and flight

The owner authorized changing the original physics starting point to achieve a
faster, more vertical arcade racer. Content 5 keeps the six circuits' X/Z control
points, ordered gates, collision model, inputs and network protocol, and revises
car statistics and elevation. Historical content 4 fixtures remain immutable.

| Car | Top-speed parameter | Acceleration | Grip |
| --- | ---: | ---: | ---: |
| Comet | 82 m/s | 18 m/s² | 27 m/s² |
| Needle | 88 m/s | 16.5 m/s² | 25 m/s² |
| Switch | 78 m/s | 20 m/s² | 30 m/s² |
| Sunset | 84 m/s | 17.5 m/s² | 26 m/s² |

These are controller parameters, not promises of exact achieved speed. Flat
Comet reaches 100 km/h in 1.650 seconds; the unchanged brake fixture stops from
100 km/h in 20.806 m. The original four roles and all common caps/drag remain.

| Course | Elevation range | Maximum centerline grade |
| --- | ---: | ---: |
| Palm Bay | 54.0 m | 18.45% |
| Citrus Pass | 72.6 m | 23.89% |
| Marina Lights | 49.0 m | 15.55% |
| Redwood Run | 83.9 m | 23.34% |
| Sunstone Canyon | 87.9 m | 23.58% |
| Pacific Summit | 103.1 m | 23.00% |

The bake still enforces the minimum radius, starting-straight and nonadjacent-road
separation checks. The grade ceiling is now 24%. All numeric control points are
published in DESIGN.md and game/content/tracks.json. Terrain, route icons and
metadata are regenerated from those actual bakes.

Summit's ramp moves to original u=.68, with 24 m paving over u=.665–.725.
It rises 1.2 m over 12 m and returns to the base surface over 50 m. A crossing at
horizontal speed ≥30 m/s replaces the original-road normal velocity with a fixed
7.2 m/s outward impulse, once per lap. Ground snap is disabled for 23 ticks,
then landing checks velocity against the supported plane normal. This avoids
mistaking ordinary uphill travel for continued ascent away from the road.

The straight collision/probe matrix covers nominal 30/45/60/80/95 m/s approaches
on −15%, flat and +15% slopes: one jump, one landing, no recovery, about
0.57–0.73 seconds airborne. A separate actual Summit matrix covers all four cars
and left/center/right approaches at the same five speed bands: 60 safe landings,
no recoveries, at most 0.85 seconds airborne. Car caps stay active; the 95 m/s
band does not assert every car reaches 95 m/s. Original .72 and intermediate .70
ramps failed high-speed outside-line landings and are not the shipped design.

The lower Near camera tracks car translation before smoothing its relative boom,
and follows a smoothed road slope. The old absolute-position smoothing could
leave it inside the road on fast descents. Cars and wheels also follow the road
normal, retaining takeoff orientation in flight. Actual collision fixtures cover
±24% grades at 85 m/s and 30/60/120 render frames/s, with the car in frame and no
boom collapse. Reduce Motion, FOV limits and camera obstruction checks remain.

Twenty-eight batched original 3D frames form Sunburst Crest, Packing Skyway,
Harbor Cranes, Timber Crest, Canyon Ribs and Summit Flight. They provide close
passing scale around climbs, crests and the launch without driving collision.
Each has one mesh, fewer than 300 triangles and at least 12 m declared clearance;
geometry checks retain a clear road/flight corridor. All 30 named landmarks and
47 source models remain. Timber Bridge and Viaduct faces are subdivided and
conformed to the actual banked/ramped road in all three LODs, preventing a flat
bridge deck from blocking the climb visually.

Repeated foliage and props meet the upper visible terrain/road-verge triangle,
including the diagonal in the exported 32 m terrain grid. Root placement is
cosmetic. Memory-pressure cleanup drops the height cache while active placed
meshes/materials remain owned by the scene.

The content 4 archive fixture checks exact saved profile/record/ghost/Cup/active
race bytes on a cold content 5 load. Existing archived times remain stored;
current-content records/ghosts start fresh, and old Cups/races cannot resume with
new handling. Game save schema 1 and network protocol 5 remain unchanged;
content identity changes to prevent old/new physics joining the same race.

Useful checks:

```sh
python3 tools/check.py
python3 tools/bot_acceptance.py --seeds 20 --jobs 3
python3 tools/soak_acceptance.py --laps 3 --seconds 2400 --clear-road-spacing
python3 tools/godot.py --max-fps 60 --script tests/shader_warmup_evidence.gd
```

The earlier .70 candidate completed 360 races / 2,880 finishes with zero DNFs or
recoveries. The final .68 full matrix and current-content network soak are
separate checks; their status belongs in STATUS.md. These scripted tests and
native renders do not establish human handling preference or physical-device
performance. The owner will do physical follow-up; our Android validation uses
emulators.
