# Hood framing, lamp attachment and runtime fixture repair

The published Build 96 Comet Hood view fills about one third of the screen with
bonnet. Four actual model profiles now set the eye's forward distance from their
centreline triangles and the current FOV; height stays 1.15 m above the road.
Front and rear silhouettes are cached as small point arrays, without retaining
additional model/texture resources. Spectator views select the followed car's
profile. Chase yaw/motion settings and all handling rules remain unchanged.

The actual native raster fixture tests **four cars × five FOVs × two settled
view directions**. All **40** centreline silhouettes measure **10.0%** bonnet.
Eight masks, twelve normal synthetic Palm Bay reference views, full JSON and
native log are in `silhouettes/`. All four normal 83-degree views were inspected.
Moving road slope, body roll/pitch and chase yaw lag can vary this fraction; the
flat control is not a claim of fixed pixel coverage during every manoeuvre.

The normal views exposed lamps floating above the low Needle nose. Editable
Blender source now attaches front/rear lamps and the grille to each car's own
end-cap width/height. Four GLBs and editable `.blend` are regenerated with Blender
5.1.2; atlas bytes, triangle counts, three LODs and handling stay unchanged. The
new asset identity is in `provenance.json`. Actual exported painted-body triangles
exclude the lamps themselves in **240 centre/corner attachment rays**, across
all four cars and all three LODs. All pass. The identical geometry check rejects
the old committed Needle asset at the first headlamp centre; `legacy-control.log`
retains that expected assertion and nonzero wrapper exit. Retrieve those exact
legacy bytes with `git show f3fa17d:assets/exported/cars/needle.glb`.

The full **92-command source matrix** passes with the revised camera/assets;
`source/` retains all full invocation logs. The six-course/36-path camera gate
uses actual Needle profiles and still has zero static overlap or cosmetic-floor
clip. The separate hill/cadence gate passes. The last mobile render-fixture
follow-up below was made after that source run and verified separately.

Strict CI 98 actually executes its Linux graphical fixtures. Car, fonts, results,
scenery, 24 course views, foliage, posters, effects, icons, HUD, menus, 32 preview
orbits, School and brake-lamp fixtures pass. It then rejects
`mobile_runtime_evidence.gd:53`; publication stays blocked. The original raw CI
log and 1920×1080 failed image are retained. Live software-render pressure can
change the policy during an eight-frame GPU readback, conflicting with this
fixture's fixed initial 80% assertion. This is a fixture-coupling diagnosis;
the original CI assertion did not print its actual scale.

The fixture now disconnects automatic feedback only during its explicitly
scripted **80% → 60% → 80%** phases, preserving the same policy, graphics and
injected memory notification. It reconnects for separate live timing samples.
Both normal native execution and an intentional **3 fps draw-cap probe** pass.
The latter records **two live quality reductions** after reconnection, proving
real feedback remains active. Its exact scope, original images and samples are
in `runtime-slow.json`; the 60 Hz physics clock, state and physics space remain
intact. This measures instrumentation and controlled resource retention, not
minimum hardware or human performance. Remote execution of this correction and
the new Hood gate remains pending at this source checkpoint.
