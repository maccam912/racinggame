# Eight-car and finite boost expansion

Trailblazer is a tall rally wagon; Corsair is a long, fast GT. Pulse and Meteor are two different turbo silhouettes, each with three two-second boosts per race and no refill. Shift, gamepad west/X/Square, or the touch Boost button activates the ability. The garage labels the inventory; the HUD/touch button shows charges.

The native [new car lineup](new-cars.png) uses the actual exported GLBs and runtime paint shader. It is a posed model reference. Car geometry keeps the shared collision footprint. All eight cars have three authored LODs, animated wheels and mounted brake/head lamps.

`tests/boost_tests.gd` covers three uses, held input, presses during a burst, no refill on laps/recovery, save/resume, input packets, authoritative inventory and prediction replay. Old content-15 saves are frozen before the controller revision; records, ghosts, Cups and suspended races are preserved but incompatible. Gameplay/content/protocol/save revisions are 16/8/1.

Car-specific AI speed lines are regenerated for all 40 roads. The road sample, distance, gate and start geometry remains exactly the reviewed content-15 geometry. `terrain_routes15.json` binds those exact road fields so adding a car does not require new terrain meshes. Whole-grid and GLB integrity checks remain enforced.

Local checks do not establish physical Android controls, human balance/feel or remote CI results. See validation.json for the completed local run.

Native posed [desktop burst](desktop-boost.png) and [touch charges](touch-boost.png) show the actual effects and controls.
