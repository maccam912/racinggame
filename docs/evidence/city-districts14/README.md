# City districts and skyline

Neon Underpass adds a cinema square, station forecourt, canal apartments, civic offices and an old tram quarter. Apartment balconies, covered shopfronts, parking decks and a cinema marquee give these places different silhouettes. The final scene contains 119 buildings. Independent polygon intersections of their actual transformed mesh bounds find no overlaps, and the existing full-radius road/foundation checks pass.

The distant city uses broad tangential building fronts with varied heights instead of narrow isolated posts. The resulting persistent mesh has 4,992 triangles, within the existing 5,000-triangle ceiling. Lantern Market's skyline has wider, lower roof groups. Neither change alters road geometry, collisions or gameplay compatibility.

The seven driving-height images per course and `native.json` photographs use the actual macOS renderer. The current shipped 512×288 course photos were refreshed. Source for the multi-view capture is included.

An isolated native eight-car Neon Underpass race completed before and after the changes, with all eight racers finishing in each run. Frame timing uses actual wall-clock `frame_post_draw` intervals, excludes loading/countdown/menu and includes OS scheduling. At the same Medium settings and 60 FPS cap, the before/after p95 was 17.466/18.017 ms and p99 was 18.491/18.827 ms. Both runs had one frame above 33 ms. This is a single Mac comparison, not a minimum-hardware, physical Android or human-driving acceptance claim.

The focused validation results are in `checks.json`; the previous full 209-command gate is retained separately in `authored-courses14`. Gameplay content hash remains `a3f19386ae963d64bef791556074983f4b45cce689f01e2e270b264b7abb05fd`.

The editor import completed its asset work but logged a Godot/macOS thread shutdown crash while quitting. It is not counted as a passing validation step. The subsequent headless parse check passed; native scene and race results above are separate runs.
