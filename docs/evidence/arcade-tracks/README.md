# Arcade track identities — 20 October 2026

The six original courses now have separately authored geometry instead of the
shared kidney-loop pattern. [Actual maps/elevation strips](layouts.svg) and
[reviewed native 1920×1080 views](lineup.jpg) show the driving and visual spread.
Marina has orthogonal downtown blocks and hard braking corners; Citrus, Redwood
and Sunstone have actual loose dirt traction, dust, rumble and unpainted rutted
roads. Summit has 150 m of height variation, three launches and wide landing
zones. Caldera's existing seven-crossing star is now a volcanic moon, with a
procedural starfield/ringed planet, luminous rails, speed gates and crystals.
The figure eight, quarry hairpins and trefoil reservoir retain their geometry.

Current gameplay `70dbe372`, cosmetics `ed9ac660`, content 10 / protocol 6 /
save schema 1. The existing in-progress steering changes remain included in the
shared workspace. Frozen historical fixtures are preserved.

- [Geometry](geometry.json): strict schemas and canonical 2 m bakes pass all ten
  courses; minimum radius, maximum grade, road separation and legal grid checks
  remain enforced. Interface route icons, terrain and seven postcards regenerated.
- [Physics](physics.json): actual main-road probes on all courses, all ten ramp
  launches/landings, repeat-trigger suppression and next-lap rearming; measured
  dirt grip/drag differ from asphalt. [Summit](summit-landings.json) passes all 180
  combinations of three ramps, four cars, five speeds and three lateral lines.
- [AI matrix](ai-matrix.json): 120 eight-car field races / 960 finishers, all ten
  courses, three difficulties and four reference-car choices; zero DNFs or
  recoveries. [Final Summit rerun](final-summit-ai.json) adds 12 races / 96 finishers
  after widening the landing zones, also with zero DNFs/recoveries. All 40
  standing-start car/course Gold trials passed before the widening.
- [GPU loading](gpu-loading.json): all ten native Compatibility worlds prepare
  and draw their actual materials, including the custom sky. Retry, cancellation,
  foreground waiting and real ENet Loaded ordering pass. Twelve shader paths,
  at most 62 submissions. Native reference captures were visually reviewed.
- [Network](network.json): both actual clients finish Citrus with matching rows
  through 50±20 ms one-way delay and 1% packet loss. Worst clear-road correction
  p95 0.036781 m; no engine or cleanup errors; final gameplay manifest stays
  unchanged throughout. Dirt and all ramp bits also round-trip in the unchanged
  727-byte snapshot.
- [Source validation](source-validation.json): full 105-command source run had
  102 passing commands and three findings: stale route icons/assets, the narrow
  first Summit landing, and missing sky-shader tracking. All are fixed; the
  separate final 11-command repair/critical-course run passes. The initial failed
  run is retained, not relabeled as a clean full rerun. Final schema, bake,
  content/asset identity and whitespace checks pass separately.

The first network attempt is retained under
`reports/network-udp-50-20-0.01-27430-48ae6c9169`: its sources changed while the
landing fix was being made, so the stability guard correctly rejected it. The
linked final network run uses the finished stable source. These are local source,
native rendering and automated driving results. Human feel, physical Android,
remote CI, full release soak and publication are separate follow-up scopes.
