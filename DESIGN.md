# Pacific Rush Game Design and Implementation Specification

Version 1.12 — 19 October 2026

Owner decisions, 19 October 2026: implementation validation uses Android phone
and tablet **emulators only**. Physical-device checks elsewhere in this document
are optional owner follow-up, not implementation/release-work blockers. Emulator
results must still be labeled accurately and never presented as physical hardware
or thermal evidence. Latest owner feedback supersedes the earlier decision to
retain exact physics: physics is a starting point and may be tuned to achieve
manic arcade speed, stronger hills/drops and dramatic set pieces. Hybrid original
illustrated billboard decorations with retained 3D structures/landmarks are
approved. Update numeric rules/content versions and repeat driving/network checks
when handling or course geometry changes; preserve historical evidence.

The owner also explicitly defers official-region hosting for now. Development
releases MUST leave both official region URLs unconfigured. Preserve working
offline modes and Community Direct Connect. Hosted-region launch requirements
below describe a later operator deployment; do not provision hosts, invent public
domains or advertise regional matchmaking as available in these checkpoints.

Working title: **Pacific Rush**. The title is provisional; title availability is not established. Product: a downloadable 3D online arcade circuit racer for Windows, macOS, Linux, and Android. This document defines the complete first release, including offline play, online services, touch controls, cross-play, content, presentation, controls, and delivery criteria.

The player request establishes five requirements: 3D presentation; online multiplayer racing; satisfying speed and cornering with skill but limited realism; the colorful late-1990s California Speed arcade atmosphere; and mobile support with touch controls. All other choices below are explicit design defaults selected to make implementation reproducible. They are normative for this version, but are not claims that the product owner previously approved each individual choice. Implement this specification before extending it. Do not add features merely because a comparable game has them.

## 1 Product contract

Race original, chunky sports cars through a fictional sunny Pacific coast region. Eight cars launch together, sweep through wide bends, brake for tighter corners, slide when deliberately provoked, and recover quickly from scrapes. A typical race lasts two to four minutes. A good player wins through line choice, controlled entry speed, and strong exits. Basic driving is immediately understandable with steer, accelerate, and brake.

The look is bright, solid, and readable: blue skies, cream concrete, orange cliffs, turquoise water, oversized palms, exaggerated hills, colorful storefronts, and simple reflective cars. The desired feeling is a lively arcade cabinet presented cleanly on modern screens. Do not reproduce California Speed's title, logos, car designs, courses, music, UI, or proprietary assets.

### 1.1 Priorities and success measures

1. Driving feels responsive: local steering affects the next simulation step; online input never waits for a server round trip.
2. Corners are learnable: the same inputs and starting state produce equivalent outcomes within the validation tolerances in section 30.
3. Speed is legible: scenery passes close enough to show motion; the road ahead remains readable; the camera does not oscillate.
4. Mistakes cost time without ending a race: ordinary wall contact does not flip a car or stop it abruptly.
5. Multiplayer is easy to enter: public rooms, private room codes, guest identities, and no account registration.
6. The entire launch game is available immediately: no purchases, performance upgrades, grind, energy, or locked cars/tracks.

First-session usability target: at least four of five new testers can start an offline race without help within 60 seconds after first-run setup, complete it, and explain how to improve a corner. This is a playtest gate, not a claim of current validation.

### 1.2 Launch scope

| Area | Required at launch |
| --- | --- |
| Players | One local player per client; 1–8 humans per online race; bots fill remaining seats to eight by default |
| Cars | Four mechanically distinct original cars; eight shared paint colors; all available immediately |
| Tracks | Eight forward circuits (six classic Cup routes plus two bonus routes); fixed weather/time of day per track; no reverse variants |
| Offline modes | Driving School, Quick Race, Time Trial, Coast Cup |
| Online modes | Public Quick Join, public/private rooms, single races, persistent lobby and rematches |
| Input | Keyboard, Xbox-style and PlayStation-style gamepads, mobile multitouch; remapping/layout adjustment; mixed-device menu use |
| Presentation | Two chase distances and hood camera; music, engines, tire feedback, limited announcer; 60 fps target |
| Records | Local best laps and trial medals; local best ghost; cup trophies; local statistics |
| Platforms | Windows x86-64, Linux x86-64, macOS Apple silicon and Intel, Android ARM64; Android phones and tablets; cross-play |
| Languages | English launch text; all text externalized for localization |

Explicitly excluded: iOS, browser, and console builds, split screen, steering-wheel force feedback, licensed vehicles, traffic vehicles, pedestrians on the track, weapons, boost pickups, nitro button, drafting bonuses, damage simulation, fuel, tuning, cash economy, online ranked play, global leaderboards, voice/text chat, friends service, spectators joining an in-progress race, user-generated courses, photo mode, full replay editor, and live-service seasons. Decorative roadside people are excluded to avoid animation scope. Online Coast Cup is not included. Tilt steering and portrait racing are also excluded; mobile uses the defined landscape touch controls.

## 2 Terminology and precedence

MUST indicates required behavior. SHOULD indicates a preference that may change only if a documented technical limitation requires it. Unqualified rules are MUST requirements. Numerical constants are initial shipping values, not loose suggestions. Where a test exposes a conflict, revise this document and the shared data together; do not silently tune a private implementation.

A **tick** is 1/60 second of simulation. A **race** has a starting grid and a finish after the configured laps. A **trial run** has a standing start and one complete lap. A **room** is an online lobby plus its current race. A **slot** is a stable racer identity within one race. A **gate** is an invisible progress plane. **s** is distance along the canonical centerline, in meters; **u** is s divided by track length, in [0,1). A **clean lap** completes all gates without recovery, wrong-way invalidation, or leaving the allowed corridor.

The document is organized as: product/rules/handling (1–9), tracks/art/UI/audio (10–17), AI/networking/persistence/technology/operations (18–25), mobile (26), and delivery/validation (27–32). Mobile rules explicitly override desktop layout/settings where stated; simulation rules remain shared.

Precedence: explicit state/rule tables and formulas take precedence over illustrative prose; race-mode exceptions take precedence over global rules; safety bounds take precedence over cosmetic presentation. A future design revision must resolve contradictions rather than leaving precedence to programmers' taste. Asset style variation within stated budgets is acceptable; different game rules, route topology, menus, or vehicle parameters are not.

## 3 Core loop and first run

Launch → first-run preferences → Main Menu → choose mode → choose car → choose event → load → countdown → race → results → retry/next race/menu. Returning players launch directly to Main Menu, remembering the last car, paint, and mode selection. No splash sequence may block input longer than two seconds; required legal marks may share the initial loading screen.

First run shows one panel with display name, speed units, and a prominent Reduce Motion toggle. Default name is Driver plus four random decimal digits. Defaults are mph and Reduce Motion off. Continue saves immediately. The next panel asks “Try Driving School?” with Start School and Skip; Skip has equal visual weight. All preferences remain available later. No account, email, age, or social login is requested.

Driving School teaches five exercises on Palm Bay using fixed spawn locations and temporary cones: accelerate and stop; follow three broad turn markers; brake into a tighter corner; hold and release a short slide; use recovery. Each exercise has a single caption, controller/keyboard icon, animated input demonstration, retry button, and Skip. It is noncompetitive and never locks other modes. An exercise completes on the objective, with no time pressure. The final panel offers Quick Race and Main Menu.

## 4 Race formats

### 4.1 Quick Race

Select track, car, paint, difficulty, laps (1, 2, or 3; default 2), opponents (0–7; default 7), and car contact (on by default). Begin immediately after confirmation. Human starts in grid slot 5 when eight cars are present; in smaller fields, use min(5, field size). Bots occupy remaining slots in roster order. The event seed is freshly generated and displayed in diagnostic exports, not regular UI. Retry repeats the same seed and grid.

### 4.2 Time Trial

Choose track and car. There are no opponents or car contact. One standing-start lap; the timer begins on GO, so launch time is included. Finish shows elapsed time, best time, medal earned, and delta against the previous best. Retry retains the loaded track, immediately restores the standing grid and starts the three-second Countdown; it skips the initial two-second camera-settle Grid phase. Race state, timer and ghost capture are fresh, while the selected track/car/paint and ghost preference remain. The previous best run for that exact track/car/handling version appears as an optional translucent ghost. Ghosts have no collision, audio, particles, or nameplate.

Times are separated by car and content version. Medal thresholds are derived from canonical track length L: Gold = round_up_to_0.1(L/43 + 7) seconds; Silver = round_up_to_0.1(1.12 × Gold); Bronze = round_up_to_0.1(1.27 × Gold). These are explicit initial targets; release playtesting must confirm Gold is achievable on every car/track without exploits. A revision to these targets changes the content version. Time Trial never records a medal or ghost for an invalid run. The timer remains visible with “Invalid run — retry to set a record.” The player may still finish.

### 4.3 Coast Cup

Offline championship across Palm Bay, Citrus Pass, Marina Lights, Redwood Run, Sunstone Canyon, and Pacific Summit in that order. Two laps each; seven Medium bots; car contact on. Choose one car before starting and keep it for the cup. First race human grid slot 5; later grids are reverse championship order, with the current leader last. Scores by finish position are 10, 8, 6, 5, 4, 3, 2, 1. DNF and disqualification score zero. Ties in total points resolve by most wins, then most second places and so on, then final-race placement, then stable roster ID. Award a local gold/silver/bronze trophy for finishing first/second/third overall. Trophy is cosmetic record data only.

Cup saves between events after results are committed. Continue Cup resumes at the next unstarted event. Quitting during a cup race restarts that event on resume, with its original seed and grid; completed results cannot be overwritten. Starting a new cup asks before replacing an unfinished cup. Retry Race is absent in cup results. An explicit Abandon Cup confirmation clears the active cup but preserves completed trophies/statistics.

### 4.4 Online single races

Room host selects track, laps (default 2), bot fill (default on), bot difficulty (default Medium), and car contact (default on). Everyone selects their own car and paint. No team mode. Public Quick Join searches the selected region for a compatible public room in Lobby with an open human seat; order by most humans, then oldest room, then room ID. If none exists, create a public room with defaults. Auto Start begins a 20-second timer once at least two humans are ready; if only one human is present, the host may start with bots. All-ready with at least two humans shortens the timer to five seconds. Unready, roster change, or settings change cancels countdown and resets the 20-second timer when the condition is next met. Host can Start when every present human is ready, including a one-human room. Nobody is forcibly marked ready.

At zero the roster and settings lock. No new entrants during Loading, Countdown, Racing, or Results; server browser shows In Race and disables Join. After results, Return to Lobby occurs automatically after 20 seconds, or immediately when all connected humans choose Ready for Lobby. Ready flags are cleared on return. Host remains room administrator, not simulation authority. There is no peer-hosted race or host migration of simulation.

## 5 Race state and scoring

### 5.1 State machine

| State | Duration or exit condition | Behavior |
| --- | --- | --- |
| Lobby | Start conditions satisfied | Selection and room administration allowed |
| Loading | All remaining humans loaded or 30-second timeout | Show track postcard, controls, and loaded count; nonloaded clients removed |
| Grid | 2 seconds | Cars frozen; camera settles; engines audible |
| Countdown | 3 seconds | Show 3, 2, 1 for one second each; inputs accepted but no movement |
| Racing | First finish then grace period, or hard limit | Show GO for 0.6 seconds; physics and timer start together |
| Finish Grace | 30 seconds from first valid finish | Remaining racers continue; finisher becomes ghost under AI control |
| Results | User action offline; 20 seconds online | Immutable standings and persistent result commit |

Race hard limit = 600 seconds, including Finish Grace. If nobody finishes, end at the limit. If all remaining eligible racers finish or DNF, end after a two-second settling period. If all humans leave online, terminate the race and free the room after 30 seconds; no public bot-only races persist. Pausing offline freezes simulation, race timer, audio pitch state, and bots. Online pause is an overlay only, with “Race continues online.”

### 5.2 Starting grid and launch

Two columns at lateral offsets ±2.5 m from centerline; four rows, 7 m apart, with front row 8 m behind the start gate. Slot 1 is left, slot 2 right, viewed in driving direction. All cars face the local tangent. The start region must provide at least 45 m of straight flat road behind the gate. Collision is disabled between cars for the first 1.5 seconds after GO; visual opacity is 75% during this interval. No rev timing bonus or false-start penalty. Holding throttle during countdown gives full normal acceleration on GO.

### 5.3 Checkpoints and finish

Place ordered gates at s = 0, 100, 200, ... meters, plus the start/finish gate at the loop seam. Gates cover the entire allowed road-and-shoulder width and 12 m vertically. A valid crossing is a swept front-to-back crossing in the forward tangent direction; reversing across a gate does not count. The initial s=0 crossing starts lap progress but does not complete a lap. A lap requires every subsequent gate in order and the next s=0 crossing. Swept crossing handles multiple gates in a tick in travel order. Teleports never grant gate progress.

Finish time is server tick plus the interpolated fraction of the swept finish crossing. Display milliseconds, retaining higher precision internally. Finished racers sort by finish time; exact ties sort by stable slot ID. Unfinished racers sort by completed laps, last valid gate index, then clamped s-distance from that gate, then slot ID. A car cannot gain rank by skipping a gate, leaving the corridor, or projecting onto another part of a track. Search centerline progress only within the current gate interval and immediate neighboring segments.

Race elapsed time and first-lap time begin at GO, including the distance from the grid to the start gate. The first crossing does not reset either timer. Subsequent valid finish-line crossings reset the lap timer. Best-lap race records and standing-start Trial records use separate mode keys, so a flying lap cannot overwrite a standing-start result.

Finishers have car contact disabled and AI drives them at 60% speed until results. Their camera remains on their own car; a Next Racer button cycles only unfinished racers, returning to their own car after the last. In online play this spectator view is available only to racers already in the race.

### 5.4 Off-road, recovery, wrong way, and inactivity

The road is playable asphalt with a 3 m shoulder on both sides unless a track interval says otherwise. Entering shoulder applies surface grip/drag rules. Beyond the outer shoulder edge by more than 2 m, or falling 8 m below local road height, requests recovery after 0.5 seconds. Recovery is immediate if below world kill height y = -80 m. Leaving the allowed road-plus-shoulder corridor for more than 0.25 seconds invalidates a trial lap even if automatic recovery has not occurred.

Manual recovery requires holding the action for 0.5 seconds. Fill a small ring around its HUD icon; releasing early cancels. In a race with opponents, remember rank and gate-bounded route progress on the last clean-road tick before departure or the first manual hold. During the fully covered midpoint of the one-second fade, rejoin the moving field near that rank: between adjacent racers, 10 m ahead of the leader for a former leader, or 10 m behind the tail for a former last-place car. Predict the remaining half-second using those racers' mean speed. Limit forward relocation to 240 m from departure and to 8 m before the current lap's finish; never award a lap or finish through recovery. Restore intervening gate state to match the destination and invalidate the recovered lap for records. Resume at the adjacent racers' mean speed, capped by 80% of car top speed and 90% of the local baked safe speed. Use the exact collision centerline, including bridge layer and ramp offsets. Finished/DNF racers cannot gain a rescue. The rank/progress anchors survive offline suspension; rolling release speed is shared in protocol 7 snapshots (743 bytes for eight cars).

Solo, Trial and School recovery retain the last crossed valid gate, 6 m behind its plane, with zero speed and unchanged gate/lap sequence. Every recovery keeps the clock running, invalidates Trial/clean-lap records, excludes teleport distance from stats, and uses the same one-second frozen fade and two-second contact grace afterward. No extra time penalty.

Wrong way appears after heading dot forward tangent < -0.25 while speed > 5 m/s for 1 second, or backward progress > 10 m. Hide after 0.5 seconds of forward travel. It does not automatically turn the car. More than 3 seconds of wrong way invalidates the current trial lap. In races, progress gates prevent backwards lap exploits.

Online input inactivity of 45 seconds marks the racer DNF, removes car contact, and shows a rejoin-lobby prompt. Pause-menu use counts as inactivity if no driving occurs. A finished racer is exempt. Offline there is no inactivity kick. All DNF reasons appear as text in results. No punishment persists across sessions.

## 6 Controls

| Action | Keyboard default | Gamepad default |
| --- | --- | --- |
| Steer | A/D or Left/Right | Left stick X |
| Accelerate | W or Up | Right trigger |
| Brake / reverse | S or Down | Left trigger |
| Handbrake | Space | South button |
| Recover | Hold R | Hold North button |
| Cycle camera | C | East button |
| Look back | Hold V | Hold right-stick click |
| Pause | Escape | Menu/Options |
| Results or menu confirm | Enter | South button |
| Back | Escape | East button |
| Menu navigation | Arrows / WASD | D-pad or left stick |

Throttle/brake are analog [0,1]. Steering is [-1,1]. A keyboard key supplies full axis value; opposite steering keys cancel to zero. Input contexts prevent menu confirmation from triggering a handbrake on the next scene. Clear held-button transitions when context changes; continuous throttle may resume only after GO. Menu repeat starts after 0.35 seconds, then repeats every 0.09 seconds. Mouse supports every menu but not steering. No mandatory mouse use.

Brake has priority over throttle for deceleration; at forward speed below 0.5 m/s, holding brake continuously for 0.35 seconds enters reverse. Reverse acceleration is 7 m/s², capped at 8 m/s. Throttle while reversing brakes at 14 m/s² until stopped, then resumes forward acceleration. There is no gear-shift input. Gamepad radial deadzone default 0.15, range 0.05–0.35. Rescale outside deadzone to full range. Analog steering response is sign(x) × abs(x)^1.3. Keyboard steering uses the same downstream smoothing as analog input.

## 7 Driving simulation

### 7.1 Model and coordinate convention

Use a custom kinematic arcade simulation. Godot's physics engine supplies static-world sweep and ground queries; the authored model supplies vehicle motion and car-to-car response. Do not use VehicleBody3D, wheel-collider tire simulation, or dynamic rigid-body chassis as the primary controller. A static-world collision backend change must pass the same tests.

World units are meters, seconds, kilograms, and radians. Godot world +Y is up. Car model forward is -Z and right is +X. Steering +1 means right. Use a signed yaw convention where positive yaw turns the forward direction toward the right; do not assume Godot's Euler sign matches this convention. State contains position, velocity, heading yaw, yaw rate, ground normal, grounded flag, steering filter, drift state/timers, recovery state/timers, progress, and input acknowledgement. Visual roll/pitch/wheel rotation are not authoritative state.

Fixed step dt = 1/60. Per tick: validate/sample input; update steer and drift state; ground probes; apply yaw; resolve longitudinal/lateral motion; apply gravity or ground constraint; sweep static world; resolve car pairs on server; update gates/recovery; emit events; snapshot if due. Client prediction follows the same order with speculative local-car contacts against estimated remote poses; only the server resolves authoritative car pairs. Use SI values internally; speedometer converts to km/h or mph.

### 7.2 Chassis and road contact

All cars use the same gameplay footprint: rounded box 1.9 m wide, 4.2 m long, 1.1 m high, with bottom at ride height 0.35 m above road. Implement an equivalent convex shape with 0.25 m corner radii. Visual meshes may vary within ±0.15 m width/length; no statistical collision advantage from model shape. Cars never roll over mechanically. Heading follows the ground plane; only the rendered body pitches/rolls beyond the smoothed road orientation.

Four downward ground probes at local x = ±0.75 m and z = ±1.35 m, originating 0.8 m above the chassis base and extending 2.5 m. A road hit within 0.65 m below desired ride height supports the car. Use average supported probe height and normalized average normals, rejecting normals more than 50 degrees from world up. At least two valid probes means grounded. Smooth the rendered ground normal with exponential rate 12/s; simulation uses the unsmoothed supported plane. On ground, set chassis base to road height + 0.35 m, retaining horizontal velocity projected onto the plane. A downward snap is limited to 0.4 m per tick and is disallowed when velocity along the supported plane normal exceeds +1 m/s after a launch.

If fewer than two probes support, use ballistic gravity 22 m/s². In air, throttle changes forward speed at only 15% of ground acceleration; brakes have no effect; steer yaw response is 20% of grounded response. No pitch/roll trick inputs. On landing, project velocity onto the road plane, multiply forward speed by 0.97, clear downward velocity, and play a brief suspension animation. No damage. Car can land safely at any yaw; excessive sideways velocity is damped by the ordinary grip model after landing.

### 7.3 Acceleration and grip equations

Let f and r be normalized forward and right tangents on the supported plane, vf = dot(v,f), and vl = dot(v,r). Let A be the car acceleration value and V its top speed. Ground acceleration with throttle T and brake B is `A*T*max(0, 1-(max(vf,0)/V)^2) - 18*B - 0.30 - 0.00010*vf*abs(vf)` in m/s² while traveling forward. Apply rolling drag only while moving; clamp a non-powered deceleration at zero rather than unintentionally reversing. Clamp powered forward speed to V; downhill/impact overspeed may reach 1.08×V and decays using an extra 6 m/s² above V. Gravity along ground tangent contributes at 40% of physical g = 9.81 m/s², so slopes matter modestly. Reverse uses section 6 instead of this forward equation.

After yaw rotates f/r, recompute vf and vl. Lateral correction is `delta_vl = -clamp(vl, -G*dt, G*dt)`; G is car grip acceleration multiplied by surface and drift factors. This removes sideways motion at a bounded rate, allowing slip when steering demand exceeds grip. No invisible rail toward the centerline, no auto-steer, no speed rubber band for humans, and no additional sideways impulse simply for entering drift. Do not normalize velocity after removing lateral motion; excessive sliding should cost speed.

Steering filter moves toward target at 5 units/s while increasing magnitude and 7 units/s while returning to zero or changing direction. Target yaw rate in degrees/s is filtered steer × car turn factor × `lerp(100, 35, clamp(abs(vf)/55,0,1)) × clamp(abs(vf)/5,0,1)`. Reverse negates yaw direction. Yaw rate moves toward target at 240 degrees/s². Apply yaw before grip. This permits tight low-speed turns but limits high-speed steering.

### 7.4 Sliding and surfaces

While grounded and traveling forward above 15 m/s, either full-lock steering or the handbrake can enter Drift after 0.10 seconds. Steering entry requires both raw and filtered steering magnitude ≥0.90 in the same direction. An existing slide stays active down to 0.75 steering magnitude, so small stick/touch fluctuations do not repeatedly restore grip. Handbrake entry requires abs(filtered steer) >0.25. Both paths multiply grip by 0.45 and yaw target by 1.20. Only the held handbrake adds forward drag of 3 m/s²; below entry speed it applies 10 m/s² braking. Parking, reverse and airborne steering cannot initiate a drift.

During grounded Drift and Recovering Grip, smoothly reduce yaw into the slide as sideslip grows: `into_slide = -sign(filtered_steer) * atan2(vl,vf)`, measured before yaw, and multiply target yaw by `lerp(1.0,0.10,smoothstep(20°,40°,into_slide))` while vf >0. Opposite steering retains full authority to catch the rear. This settles sustained full lock into a controlled arc without hard-clamping velocity or adding sideways impulses. Easing steering below the hold threshold, countersteering without the handbrake, or dropping below entry speed starts Recovering Grip: interpolate grip factor from 0.45 to 1 over 0.40 seconds and yaw multiplier from 1.20 to 1. Re-entering through either input resets recovery into Drift. Cars cannot roll over.

This handling revision is **content 10, save schema 1**. All modes, bots and client prediction use the shared controller and existing drift snapshot fields. Preserve frozen content-9 profile/records/ghost/Cup/active-race bytes and earlier archives; incompatible results remain archived and continuation stays disabled. The concurrent course revision determines the combined protocol version; steering drift itself adds no packet fields.

| Surface | Grip multiplier | Extra forward drag | Feedback |
| --- | --- | --- | --- |
| Asphalt | 1.00 | 0 | White-gray tire smoke only during high slip |
| Painted road markings | 1.00 | 0 | No handling change |
| Sand / dirt shoulder | 0.65 | 5 m/s² | Tan dust, lower engine tone |
| Grass shoulder | 0.70 | 6 m/s² | Sparse grass flecks |
| Tunnel / bridge | 1.00 | 0 | Audio/environment change only |

Shoulder drag applies above 12 m/s and cannot alone reverse a car. No wet/ice surface in launch content. Slip feedback begins at abs(vl) > 3 m/s; tire squeal intensity saturates at 10 m/s. Brake lights illuminate for B > 0.1 or handbrake. No drift score, boost reward, or drift requirement; clean grip driving must remain viable.

### 7.5 Walls and other cars

Use continuous shape sweeps against track barriers and static geometry with up to four slide iterations per tick. On contact, remove inward normal velocity; retain 96% of tangential velocity for the first impact. Persistent contact in subsequent ticks applies tangential drag of 2 m/s², not another 4% loss each tick. A new impact requires separation > 0.2 m for at least 0.2 seconds. No wall bounce impulse. Visual sparks and a 0.12-second shake may occur, capped by motion settings.

For car contact, the server handles each pair once per tick in ascending slot-pair order using convex overlap/sweep results. All cars have effective collision mass 1000 kg regardless of appearance. Separate overlap equally, at most 0.25 m per car per tick, using the shortest planar separating direction. Apply normal impulse with restitution 0.05 only when closing; clamp each car's resulting impulse velocity change to 4 m/s per tick. Preserve tangential velocity; impose no angular impulse. Resolve a maximum of two pair passes per tick. Never transfer a car impulse into a static wall; sweep positional corrections against world geometry. This creates bumping and passing without violent pileups. Contact off means all cars ignore each other but still hit the world. Ghost cars have no contact in either direction.

## 8 Cars and customization

| ID and name | Silhouette and color default | Top speed V | Acceleration A | Grip G | Turn factor | Intended role |
| --- | --- | --- | --- | --- | --- | --- |
| comet / Comet | Compact rounded coupe, coral | 82 m/s | 18.0 m/s² | 27 m/s² | 1.00 | Default balanced car |
| needle / Needle | Low wedge sports car, turquoise | 88 m/s | 16.5 m/s² | 25 m/s² | 0.94 | Fast straights, careful entries |
| switch / Switch | Short boxy hatch, yellow | 78 m/s | 20.0 m/s² | 30 m/s² | 1.08 | Strong exits, easy corners |
| sunset / Sunset | Broad classic coupe, purple | 84 m/s | 17.5 m/s² | 26 m/s² | 0.98 | Stable visual presence, mild slide bias |

All other simulation parameters are shared. Car stats in the garage show numerical top speed converted to selected units, plus labeled acceleration and grip bars derived linearly from the values above. Do not invent hidden perks. The chosen default is Comet with coral paint. Each car must be within 5% of the fastest car's median expert clean time over the full six-track set; individual tracks may favor a car. If not, tuning requires a documented data revision.

Eight colors: coral #F16B50, turquoise #20BFC5, sunshine #F3CD48, violet #8465CC, sky #498DD3, cream #F5EBD3, mint #79C697, charcoal #343C49. Each car has one fixed contrasting stripe placement; stripe color auto-selects cream on dark paints and charcoal on light paints. No RGB picker, decals editor, wheel variants, stats upgrades, body kits, or paint unlocks. Player number on doors is current grid slot, not a selectable cosmetic. Four wheel meshes rotate with speed and front wheels steer visually up to 25 degrees.

## 9 Camera and sensation of speed

Near Chase: anchor 5.0 m behind chassis center and 1.65 m above road; aim at a point 10 m ahead and 0.8 m above the chassis base. Default Far Chase: 8.2 m behind, 3.4 m high, aim 12 m ahead. Hood: eye 1.15 m above road, with approximately 10% visible hood at screen bottom; no interior cockpit. Derive its forward offset from the actual car's cached centreline silhouette and current vertical FOV, rather than one fixed offset that fills the view on longer cars or hides shorter bonnets. Look-back uses the rear silhouette. The lower Near anchor is the owner's approved arcade-speed presentation revision.

Chase translation follows with exponential rate 10/s; yaw with 8/s. Frame-rate-independent coefficient is 1-exp(-rate*render_dt). Camera may lag yaw at most 12 degrees behind vehicle heading. Look-ahead shifts laterally by up to 1.0 m in steering direction, smoothing at 4/s. Chase collision sphere radius 0.25 m shortens boom against scenery and restores over 0.3 seconds. Camera never goes below the local road. Look Back uses a front-facing equivalent mount with a 0.12-second blend; release restores prior camera.

Base vertical FOV = 65 degrees at 16:9, increasing linearly by up to 18 degrees from 15 to 70 m/s; clamp outside and cap final FOV at 95 degrees. Settings adjust base FOV 55–85. Expansion approaches its target exponentially at 6/s to avoid sudden speed-induced camera changes. Dynamic FOV can be disabled. Do not use horizontal FOV values for this contract. Speed shake is zero by default; collision shake ≤0.025 m translation and ≤0.4 degrees rotation, lasting 0.12 seconds. Rendered chassis roll toward the outside of the turn is capped at 4 degrees, braking pitch at 2 degrees, landing compression at 0.12 m for 0.2 seconds. Reduce Motion removes shake, dynamic FOV, and chassis-camera pitch coupling; it does not change physics.

No full-screen speed lines, radial blur, chromatic aberration, film grain, head bob, or mandatory motion blur. Speed comes from road markings at 12 m spacing, palms/barrier posts passing at road edges, tire/engine audio, and the camera's low sight line. Preserve view of the next 120 m of road on ordinary straights; signed blind crests are the only exception.

Bonnet framing uses the actual model centreline contour. Details hidden inside
the camera's 0.15 m near clipping plane cannot shift the eye away from the
visible bonnet contour.

## 10 Track construction contract

Eight closed circuits share a canonical route generator, ensuring independently built versions have the same layout. Points in section 11 are (X,Y,Z) in meters and are traversed in listed order, looping to point 0. Generate a uniform closed Catmull–Rom curve with standard 0.5 tension: `C(t)=0.5*((2*P1)+(-P0+P2)*t+(2*P0-5*P1+4*P2-P3)*t²+(-P0+3*P1-3*P2+P3)*t³)` for each P1→P2 span. Sample each span at 256 equal t intervals, make an arc-length lookup, then resample at 2 m intervals. Final closing sample joins the first exactly. Track length L is the measured 3D arc length; use the same baked route resource on client/server. Do not hand-adjust route points or use a different spline.

Road cross section is centered on the route. Default paved width 16 m, shoulder 3 m each side. Cross-slope is flat; bank only intervals explicitly listed, with 20 m smoothstep ramps. Right vector = normalized forward cross world-up, using the forward direction of traversal; verify its sign against car-local +X. Mesh quads every 2 m longitudinally, subdivide cross-section at center and pavement/shoulder boundaries. Collision surface uses the same sampled geometry. Decorative asphalt meshes must not create seams or extra colliders.

Because the closed spline's point 0 is not guaranteed straight, the start line is chosen by a deterministic bake: among 2 m samples at least 100 m from any bank/jump interval, choose the first with maximum absolute curvature over the preceding 45 m and following 70 m below 0.0025/m and grade magnitude below 0.03. Search from original point 0; fail the track build if none qualifies. Rotate s so the chosen sample becomes s=0. Interval markers and landmarks in section 11 use **original curve u before start-line rotation**; checkpoints, grid, and race progress use rotated s. Store both in the bake. This avoids art shifting when start placement is verified.

If the provided points fail a geometric acceptance gate, produce a reported geometry correction and update these points before content production. Do not silently choose a different circuit. Minimum centerline radius 28 m; maximum grade 24%; paved edges must not self-intersect; no two nonadjacent road sections may approach within combined half widths + 8 m unless vertical separation exceeds 10 m. Track builders must run these checks before declaring the layout accepted.

Road barriers are continuous 0.9 m high cream concrete on drop-offs, and 0.8 m guardrails elsewhere. An outer shoulder may be grass/sand but must not hide an unmarked solid object. Put scenery colliders at least 2 m outside the allowed shoulder. Small cones, signs, umbrellas, and plants are noncolliding. No destructible physics props. Add a direction chevron before any bend tighter than 80 m radius, visible 80 m before turn entry. Mark every recovery zone and kill volume in editor tools.

Track-specific road-width overrides transition over 30 m. Track lighting/time of day is cosmetic and never changes during a race. Opponents and road edges must remain distinguishable without relying on bloom, shadows, or fog quality. Track thumbnails are fixed camera renders with no text baked into images.

Authoring checks for these coordinates measured the following base-route lengths and approximate minimum horizontal radii at 2 m sampling: Palm Bay 3098.3 m / 43.8 m; Citrus Pass 3245.5 / 31.4; Marina Lights 3058.6 / 34.9; Redwood Run 3271.3 / 43.5; Sunstone Canyon 3727.1 / 38.5; Pacific Summit 3947.8 / 45.0. All base grades are below 4.8%, and each route has a candidate start interval satisfying the straight/grade test. These are mathematical document checks, not engine collision validation. The final bake must still test mesh-edge intersection, bank/ramp deformations, recovery points, and actual driving.

## 11 Track roster and exact route seeds

The classic six and Skyline Splice have sixteen control points; Quarry Switchback has twenty-four. The generator accepts 16–32 points. Index 0 is an authoring origin, not necessarily the race start. Coordinates are part of the content contract. Roadside landmark placement is at the listed original u, with lateral offsets measured from road center, positive on the right. Position tolerances for major landmarks are ±5 m longitudinally and ±2 m laterally. Decorative filler may vary within section 12's density rules.

### 11.1 Palm Bay

Introductory coastal oval with broad changing-radius bends. Midday, clear sky, turquoise sea on the east side. Asphalt 18 m; sand shoulders. The most forgiving course, with no tunnels or forced jumps.

Route points: `(0,4,0), (0,4,-200), (0,4,-400), (80,12,-620), (240,38,-760), (460,58,-800), (680,32,-740), (820,8,-560), (860,4,-340), (820,4,-100), (700,4,100), (520,18,200), (320,38,220), (140,12,180), (20,4,120), (0,4,60)`.

Landmarks: u=.12 surf shop at -25 m; .28 lighthouse at +45 m; .42 pier extending +120 m toward sea; .65 beach hotel at -40 m; .82 giant sun-shaped roadside sign at +25 m. Use two rows of palms on the inland side. Horizon water begins outside right-side barriers from u=.20 to .65. No drivable beach shortcut.

### 11.2 Citrus Pass

Orchard roads and orange foothills, late afternoon. Asphalt 16 m; grass shoulders; no jumps. Broad ascent followed by a descending series of bends. Banks: u=.30–.40, 6 degrees toward inside; .66–.75, 5 degrees toward inside. Bank direction follows curvature sign and ramps to zero at inflections.

Route points: `(0,8,0), (0,8,-200), (0,8,-400), (100,20.32,-620), (340,50.86,-760), (560,80.56,-700), (700,65.6,-520), (620,31.58,-340), (820,12.94,-160), (900,14.84,60), (760,42.02,240), (520,63.3,300), (320,23.8,240), (180,8,160), (40,8,120), (0,8,60)`.

Landmarks: u=.15 fruit stand at -25 m; .32 white water tower at +45 m; .49 packing shed at -30 m; .68 orange arch spanning road with 8 m clearance; .86 windmill at +35 m. Orchard trees in 10 m rows outside the corridor; orange rock terraces beyond them. No real-world brand labels.

### 11.3 Marina Lights

Fictional waterfront entertainment district at bright blue hour. The road remains evenly lit; sky still blue, never black. Asphalt 16 m, narrowing to 14 m at u=.35–.55; paved shoulders use asphalt physics. No rain or reflective puddles. Neon is limited to colored signs and facade strips.

Route points: `(0,3,0), (0,3,-200), (0,3,-400), (120,8,-600), (360,32,-640), (580,52,-560), (620,28,-340), (500,5,-200), (620,3,-40), (740,3,180), (580,18,360), (360,40,380), (160,14,300), (40,3,200), (0,3,120), (0,3,60)`.

Landmarks: u=.12 arcade facade at -22 m; .31 illuminated marina wheel at +65 m, 45 m diameter, static; .46 short underpass from u=.44–.49 with 7 m clearance; .64 moored sailboats beyond +35 m; .81 seafood diner at -24 m. All boats are static. Window glow is emissive, not hundreds of individual lights. Tight turns use large yellow chevrons.

### 11.4 Redwood Run

Tall simplified redwoods, shafts of warm afternoon light, pale road edges. Asphalt 16 m; grass shoulders. Trees may enclose the view but never obscure the turn entry. Bank u=.25–.36 at 7 degrees toward inside. A log visitor-center sculpture is visual only; no road-spanning tree collision gimmick.

Route points: `(0,10,0), (0,10,-200), (0,10,-400), (120,26.6,-620), (360,64.12,-760), (600,93.92,-640), (660,56.96,-420), (520,18.28,-240), (700,27.44,-40), (760,67.56,180), (580,87.36,360), (340,40.08,400), (160,12,300), (40,10,200), (0,10,120), (0,10,60)`.

Landmarks: u=.13 ranger kiosk at -24 m; .30 giant tree at +28 m with trunk diameter 7 m; .47 timber bridge with fixed deck and 3 m shoulders; .63 visitor center at -40 m; .82 redwood cross-section display at +25 m. Large trunks must remain at least 5 m beyond shoulders. Background forest is clustered cards/low-detail meshes with no collision.

### 11.5 Sunstone Canyon

Orange mesas, clear sky, cream guardrails, one tunnel. Asphalt 16 m; sand shoulders. Long sight lines contrast with one tighter reversal. Bank u=.27–.39 at 8 degrees inward; tunnel u=.57–.64, clearance 8 m, ambient lighting no darker than 50% of exterior road luminance.

Route points: `(0,12,0), (0,12,-200), (0,12,-400), (140,28.6,-640), (400,67.84,-800), (680,99.92,-680), (760,62.96,-440), (580,20.56,-240), (800,18.28,-40), (940,46.96,200), (760,75.64,420), (500,25.76,460), (260,12,340), (80,12,220), (0,12,120), (0,12,60)`.

Landmarks: u=.16 roadside dinosaur sculpture at -30 m; .33 twin mesa silhouettes beyond +120 m; .48 abandoned rail trestle at -60 m; .60 tunnel portal/canyon opening; .79 motel sign at +30 m. Sand never blows across the playable road. No falling rocks or dynamic hazards.

### 11.6 Pacific Summit

Final course combining mountain overlook, ocean horizon, a sweeping descent, and one explicit low jump. Warm golden afternoon with blue shadows. Asphalt 16 m, widening to 24 m over jump zone. Grass shoulders except sand on u=.70–.90. Bank u=.30–.41 at 8 degrees inward.

Route points: `(0,20,0), (0,20,-200), (0,20,-400), (160,42.96,-660), (420,82.88,-820), (720,123.12,-700), (820,88.32,-440), (640,38,-220), (860,28.56,0), (1000,57.12,260), (800,94.88,500), (520,43.04,520), (280,20,380), (80,20,240), (0,20,120), (0,20,60)`.

Landmarks: u=.14 observatory at -65 m; .33 overlook platform at +35 m; .50 mountain lodge at -45 m; .69 coastal viaduct at +0 m supporting road; .84 balloon cluster beyond +60 m, static. The viaduct is continuously driveable, without gaps.

Jump marker at original u=.68, with a 24 m paved corridor over u=.665–.725: place a 12 m ramp rising by 1.2 m relative to ordinary road, then a 50 m smooth descent back to the original surface. At a crest crossing with horizontal speed ≥30 m/s, once per lap per car, remove velocity along the original road normal and add a fixed 7.2 m/s impulse along that normal. The base normal follows the route grade without the ramp offset. Disable ground snap for 23 simulation ticks; afterward require velocity along the supported plane normal ≤1 m/s. Slower cars drive over the full-width ramp normally. No bottomless gap. Paint yellow bars before it and a white landing stripe at crest+50 m. Straight collision/probe fixtures covering −15%, flat and +15% grades and nominal 30/45/60/80/95 m/s approaches produce about 0.57–0.73 seconds airborne; actual course flight depends on slope and line. The .68 crest replaces the old .72 crest because high-speed flights at .72 overshot the curved downhill landing; .70 also failed an outside-line 95 m/s approach. Actual .68 course fixtures cover left/center/right approaches through 95 m/s, separately from the straight fixtures. The bake retains base-curve progress length, while road collision includes the ramp deformation. This is content version 5; preserve content 4 records/ghosts/Cups/active-race bytes as historical archives, and start fresh current-content timing/continuation.

### 11.7 Shared course furniture

One start gantry per track, 6 m tall and 22 m wide, with checker band, track name, and three countdown lamps. Timing gates after the start are invisible; do not place giant glowing rings. At least one landmark visible from each third of a lap. Add original batched 3D structure sequences at the main crests: Sunburst Crest, Packing Skyway, Harbor Cranes, Timber Crest, Canyon Ribs and Summit Flight. These frame climbs and drops without adding driving collision; keep the driving/flight corridor clear. Timber Bridge and Viaduct artwork must follow the actual banked, ramped road in every detail level. Road center marking: cream broken stripes, 4 m painted / 8 m gap, 0.18 m wide. Edge marking 0.25 m cream. Use arrow boards at radius <80 m and advance warning at radius <45 m. Route direction is unambiguous at every decorative intersection, which must be blocked with visible barriers.

Each course also has three original painted travel signs on static 3D frames, outside the driving corridor. The ten illustrated panels use the canonical course names, mipmapped textures and no driving collision. Small vegetation sightlines keep the signs visible on approach. These are scenery; route guidance remains the existing chevrons and warning boards.

No alternate routes or shortcuts at launch. Visible inaccessible roads may exist beyond barriers, but must not look like missed race branches. Minimap depicts only the actual circuit. Track selection shows difficulty in words: Palm Bay Easy; Citrus Pass Easy; Marina Lights Medium; Redwood Run Medium; Sunstone Canyon Hard; Pacific Summit Hard.

### 11.8 Skyline Splice — bonus circuit

A layered harbor-city figure eight, 4,827.683369 m long, with a 180 m elevation difference at its crossing. The two branches remain ordinary shared collision surfaces; road hints, gates, recovery and checkpoint restoration keep the correct branch. Minimum horizontal radius 73.202 m; maximum base grade 16.156%. Asphalt shoulders, no banking, a ramp at original u=.50 and 24 m pavement through u=.485–.545. The bridge has cosmetic deck sides, underside and pylons; supports cannot intrude into the lower branch. Ground scenery stays on low terrain; deck lights and travel signs stay beside the road. Original chunky tower blocks rise through road height. Five landmarks: marina wheel (.15,+68), arcade (.32,−55), sailboats (.62,+64), lighthouse (.78,+70), seafood diner (.89,−48). Reuses the Marina music theme.

### 11.9 Quarry Switchback — bonus circuit

A 6,409.125648 m chain of climbs, reversals and linked switchbacks with twenty-four control points, rather than a second figure eight. Minimum radius 34.490 m; maximum base grade 15.631%; approximately 135 m of height variation. Asphalt road with sand shoulders, no bank or marked jump. Cosmetic verges narrow to 18 m beyond the pavement edge so they cannot form floating plates across nearby switchbacks. Grey-green faceted bluffs, close boulders, cut-log piles and two illustrated stepped waterfalls with animated pools distinguish the route. Five landmarks: rail trestle (.15,−60), water tower (.32,+45), packing shed (.50,−50), dinosaur (.69,+58), motel sign (.85,+35). Reuses the Canyon music theme.

For both bonus courses, exact coordinates and starting sample are normative in `game/content/tracks.json` and the checked-in canonical bakes. Existing six course definitions/bakes remain unchanged. All eight courses are immediately available in Quick Race, Time Trial and Community rooms; the six-event Coast Cup remains its existing ordered roster. This expansion is content version 6, protocol 5, save schema 1: older records/ghosts/Cups/checkpoints remain preserved but cannot continue under the new catalog hash. Frozen content-4 and content-5 fixtures must not be rewritten.

### 11.10 Spillway Sprint — bonus circuit

A 7,457.229632 m interwoven trefoil road network through fictional reservoir waterworks. Three crossings have approximately 68 m of physical separation. The 27 control points form three interlocking lobes, including a flat starting straight; minimum horizontal radius 80.147 m and maximum base grade 17.086%. Continuous 16 m asphalt, 3 m asphalt shoulders, no banking or marked jump. Exact coordinates and starting sample 91 are normative in `game/content/tracks.json` and its canonical bake. Reuses the Palm race composition.

Original pale concrete arches rise above the driver's horizon beside the road. The existing original painted waterfall cutout extends through their openings with preserved scale, shared materials, animated floor pools and 3D base rocks. Turquoise reservoir water and distant faceted cliff silhouettes frame the layered bridges. Five existing original landmarks are arranged at water tower (.13,+80), windmill (.29,−85), rail trestle (.47,+78), lighthouse (.65,−90) and overlook (.83,+75). Reservoir Ribs frames the .30 crest. All structural footprints and supports stay clear of every crossing branch; scenery introduces no driving collision or water hazards.

Waterworks piers also carry projecting control houses in three paint variants,
front/side glazing, supported platforms, clamped pipes, maintenance ladders,
shaft-mounted sluice wheels and static truss cranes/hoists. These merge into
the existing pier mesh/material and remain inside its reserved 26 m disk;
they add no driving collision or interactive machinery.

### 11.11 Caldera Crosscut — bonus circuit

An 8,869.065398 m seven-point crosscut through a fictional volcanic landscape. Seven separated crossings connect long straights and tight turns; the 28 control points have traversal vertex heights 40, 40, 260, 210, 260, 150 and 40 m. Minimum horizontal radius 30.756 m and maximum base grade 18.038%. Continuous 16 m asphalt, 3 m asphalt shoulders, no banking or marked jump. Exact coordinates and starting sample 64 are normative in the content definition and bake. Reuses the Canyon race composition.

A central multi-ring basalt crater, distant illuminated lava surface, wide roadside basalt formations and surrounding volcanic ridges provide original 3D scenery. The crater's complete 300 m footprint remains outside every road branch. Original strata/dither shading filters fine detail with distance; lava motion is cosmetic. Five existing original landmarks are observatory (.12,−85), dinosaur (.29,+85), twin mesas (.46,−95), motel sign (.65,+75) and balloons (.84,−100). Geothermal Gate frames .45. Lava, rock and structures have no hazard or driving-collision mechanics.

Both courses have three original painted travel billboards, canonical minimaps, native-rendered postcards, distinct palettes and immediate access in Quick Race, Time Trial and Community rooms. All previous eight route definitions and bakes retain their exact bytes. The six-event Coast Cup stays unchanged. This expansion is **content 9, protocol 5, save schema 1**. Preserve the immutable content-8 profile/record/ghost/Cup/active-race fixture and all earlier archives; incompatible continuation stays disabled. Additional courses do not alter vehicle handling or the packet layout.

## 12 Art direction and asset specification

### 12.1 Visual language

World shapes are clean, broad, and mildly exaggerated: palm trunks taper, hotel windows are grouped blocks, rock strata form large planes, car wheel arches are prominent. Vehicles have readable silhouettes at 100 m. Avoid photoreal scan textures, distressed grunge on every surface, tiny clutter, cinematic desaturation, cyberpunk styling, and deliberate PS1 vertex wobble. Use crisp perspective-correct rendering with an optional low-resolution presentation setting; the default image is clean native resolution.

Primary palette: sky #65B9EB, horizon #B9E6ED, sea #31BFC1, cream #F3E4C4, sandstone #D58C53, terracotta #B96344, leaf green #5E9654, dark foliage #2F6650, asphalt #646B75. Sunlight warm cream, shadows cool blue-gray. Keep the road at least 20% luminance-separated from surrounding terrain in each course's neutral reference screenshot. Cars use section 8 colors; distant rivals receive a subtle readable silhouette through normal material lighting, not wall-penetrating outlines.

### 12.2 Modeling, materials, and budgets

| Asset | LOD0 triangle budget | Texture budget | LOD behavior |
| --- | --- | --- | --- |
| Car including wheels | 8,000–12,000 | One 1024² base-color atlas plus optional 512² masks | LOD1 ≤4,000 at 35 m; LOD2 ≤1,200 at 90 m |
| Major landmark | ≤20,000 | One 1024² atlas | 50% mesh at 100 m; silhouette at 250 m |
| Modular building | ≤3,000 | Shared 1024² neighborhood atlas | 50% at 80 m; 25% at 180 m |
| Tree / palm | ≤1,200 | Shared 512² foliage atlas | ≤200 triangles at 70 m; grouped impostor at 180 m |
| Small roadside prop | ≤500 | Shared 512² prop atlas | Cull after 100 m unless directional signage |

These are ceilings, not reasons to add triangles. Cars retain their original
panel atlas and role masks, with static object-space ordered dither, restrained
metal flakes and stylized sky/horizon coating. Paint roughness is 0.23–0.31 and
metallic 0.4 (cream stripes 0.3); opaque glass has broad illustrated reflection
sweeps, and rims/chrome use roughness 0.18 and metallic 0.75. Distance filtering
fades fine paint detail before it becomes subpixel. Brake/headlamp role behavior,
ghost alpha and recovery fades remain explicit and readable. No animated noise
or environment capture is required. Near/middle car LODs have fitted
painted window pillars, rubber seals, paired wipers, rear defroster lines,
segmented lamp trim and rear plate/fascia detail. Needle adds rear-deck vents;
Sunset uses a chrome bumper. Their silhouettes, authoring dimensions, atlas,
five-part draw structure and distant LODs remain unchanged.

Dry asphalt has muted aggregate, broad weathering and four subtle tire-wear
paths, roughness 0.94 and no mirror reflection. Render-only road UVs encode metres
along the route and normalized lateral position; they do not change the shared
collision geometry or handling. Paved shoulders share aggregate with tire wear
disabled. Fade fine grain with derivatives at distance, keeping cream edges and
center marks clear. Texture filtering is bilinear with mipmaps and anisotropic
filtering; no mandatory nearest-neighbor pixel crawl. Normal maps are optional
for broad material response, not microdetail. Use one directional sun, ambient
sky, baked/static lighting for environment, and blob or simple dynamic car
shadows. No real-time global illumination or ray tracing requirement.

Roadside density measured along road: near props average one per 12–20 m on decorated sides, trees one per 15–30 m, a major landmark every 400–700 m. Keep an unobstructed 3 m vertical wedge above the visible road surface in the driving view. Interior building rooms are not modeled. Water is a flat tinted surface with two scrolling normal layers and a broad reflection tint; it never needs physical simulation.

### 12.3 Effects

Tire smoke maximum 40 particles per local car and 15 per remote car; fade in 0.6 seconds. Dust maximum 30/10, fade 0.8 seconds. Wall sparks maximum 12 per event and 8 events/s globally. Landing dust maximum 12. Skid marks are dark translucent strips, maximum 200 m per car, recycling oldest segments; lifetime 15 seconds. Skid marks and particles never affect collision, progress, or network state. Remote effects derive from snapshot slip/contact event flags. Reduce Motion does not remove useful tire smoke, but Reduced Effects can halve counts; Off removes particles while retaining brake lights and audio.

### 12.4 Asset inventory

Approved hybrid presentation: painted alpha-cutout cylindrical billboard cards
replace the repeated palm, orchard, redwood, shrub and grass rendering. Keep their original 3D
source models and retain 3D cars, road, barriers, buildings, bridges, tunnels and
major landmarks. Original generated PNGs, provenance, exact hashes and UV bounds
ship with the project. Mipmapped alpha scissor and rotation-invariant instance
bounds prevent translucent sorting and edge-on disappearance. Palm spacing is
16 m on decorated sides; nearest tree centers sit 7 m (palm), 8–9 m (redwood), or
9 m (orchard) beyond the pavement edge. Original route/driving collision stays
separate from these cosmetic placements.

Smaller original 3D roadside scenes distinguish the early courses between their
major landmarks. Palm Bay alternates selected boulder sites with five surf huts
and five umbrella/lounge/board-rack arrangements. Citrus Pass keeps its cut logs
and adds four produce-pallet arrangements with braced crates and faceted oranges.
Marina Lights gains ten paired corrugated cargo stacks with short-end doors and
locking rods. Reuse the existing seven-metre circular clearances and shared
vertex-color material; each scene is one surface under 500 triangles, has no
collision, and faces the road. Four paint variants, closed porch ceilings and
two-sided umbrella cloth remain readable from driving height. All other roads,
terrain, landmark anchors and foliage clearances retain their original layout.

Required deliverables: four car meshes with three LODs each; eight paint materials; ten track meshes/collision sets/minimaps/thumbnails; one common road kit (straight surface material, barrier, guardrail, signs, gantry, tunnel light); ten themed course arrangements with five named landmarks each; palm, orchard tree, redwood, shrub and grass assets; ten sky/lighting presets; tire smoke/dust/spark/skid materials; UI icons for all input actions, cars, tracks, settings tabs, connectivity, recovery, medals and trophies. Reuse shared assets deliberately, but every course must retain its five named landmarks and distinct silhouette/palette.

All source meshes, editable textures, font licenses, music licenses, and import settings ship in the source handoff. Use original or explicitly redistribution-compatible assets. Maintain an asset manifest with creator, source URL if applicable, license, modifications, and attribution requirement. No asset may be “temporary” in a release build.

## 13 UI design system

Reference canvas 1920×1080, 5% safe area. Scale with viewport height, preserving minimum logical button height 48 px at 1080p. At 1280×720, text must remain at least 16 physical pixels for body copy. UI scale options 90%, 100%, 110%, 125%, 150%; scale may reflow menus, never clip required actions. Support 16:9, 16:10, and 21:9; anchor HUD to the safe area, keep menu content within a centered 16:9 region. At 4:3, use a vertically scrolling menu layout; gameplay may render normally with HUD reflow.

Use the original **Pacific Rush Display** arcade face for section headings,
buttons, large speed digits and race banners. Its chunky chamfered letterforms
slant forward, use uppercase forms and equal-advance digits. Use bundled Rajdhani
SemiBold for descriptions, names, input fields and timers; keep the explicit Noto
emoji fallback. Ship editable display-font source and licenses. The main title is
an original transparent illustrated wordmark with airbrushed chrome, warm gradient
faces, deep extrusions and checkerboard flourishes. Buttons have cobalt/purple
faces, chunky gold bevels, gloss, checker accents and magenta details. Panels use
opaque deep-purple chrome frames; static checker/halftone/speed-slash artwork fills
plain menu backgrounds. High Contrast retains opaque flat panels and clear focus
borders. Scale fonts with the existing responsive layout; use scrollable content
and persistent footers at large text sizes. Main text #F8F4E8; focus yellow
#F3CD48; selected accent turquoise #20BFC5; error coral #F16B50. Color is always
paired with icon/text/state change. Preserve existing Reduce Motion behavior.

Use squared panels with 8 px corner radius, 2 px bright border on focused controls, and a small right-pointing triangle for focus. No glass blur dependency. Focus transition 0.10 seconds; screen transition horizontal slide 0.18 seconds, replaced by instant cut under Reduce Motion. Sound and visual change confirm clicks. Disabled controls explain why on focus. Tooltips appear after 0.5 seconds of focus and disappear on navigation. No hover-only information.

## 14 Complete menu and screen inventory

### 14.1 Main Menu

Left vertical choices in exact order: Play Online, Quick Race, Time Trial, Coast Cup, Driving School, Garage, Settings, Credits, Quit. Right two-thirds shows the selected car on a Palm Bay turnout with a slow 20-second camera orbit; Reduce Motion freezes the camera. Bottom left: display name and Edit Name. Bottom right: build number and online status (Online, Offline, or Connecting). Main Menu remains functional without network access. Last-selected menu item is restored after returning from a subpage, except first run defaults to Quick Race.

### 14.2 Garage and car selection

Four horizontal car cards, name, role sentence, three stats, rotate preview with mouse drag or right stick, eight labeled color swatches, Confirm and Back. Left/right shoulder buttons cycle cars. The standalone Garage saves selection and returns to Main Menu. Mode-entry selection uses the same component with Continue. No upgrade slot silhouettes or locked-item teasers. If the selected car is unavailable due to corrupted content, show a clear installation error instead of substituting another car silently.

### 14.3 Track and event selection

Six track cards in a 3×2 grid. Each shows thumbnail, name, difficulty, measured length in selected distance units, and best trial medal for selected car where applicable. Focus opens a route minimap and one-sentence description. Quick Race adds Laps, Opponents, Difficulty, Car Contact, and Start Race. Time Trial adds Ghost (on/off), standing-start explanation, personal best, and Start Trial. Coast Cup displays the ordered six-course list, rules, Start Cup or Continue Cup, and Abandon Cup when relevant. Back returns to car selection without discarding choices.

### 14.4 Online hub

Buttons: Quick Join, Browse Rooms, Create Room, Join Code, Direct Connect, Back. Region selector: Auto, US Central, Europe West; Auto pings both and picks the lower median of three probes. A region can be temporarily unavailable and then appears disabled with explanation. Actual deployment must provide both named regions before claiming complete online launch; development may show only explicitly labeled Test Region.

Browse Rooms columns: room name, track, humans/8, ping, state, contact on/off. Default filter Available Rooms on; optional Show In Race. Refresh every 10 seconds and on button press. Sorting defaults to ping, then human count descending, then room ID. Join has a 10-second timeout with Retry and Back. Empty list says “No open rooms. Create one or use Quick Join.” An unreachable service says “Can't reach the room service. Offline modes and Direct Connect are still available.”

Create Room fields: public/private, room name (default “Driver's Race”), region, track, laps, bot fill, bot difficulty, car contact. Public names 3–24 display characters, no markup or line breaks. Private rooms receive an eight-character code from alphabet 23456789ABCDEFGHJKLMNPQRSTUVWXYZ, displayed as XXXX-XXXX; separator optional on entry. Codes are access locators, not personal identities. Join Code shows generic “Room not available” for nonexistent, closed, or denied rooms. Direct Connect accepts hostname/IP plus port and optional room code, with explicit format validation and no automatic local network scanning.

### 14.5 Lobby

Left: eight-slot roster with name, car icon/name, paint swatch, ready state, ping. Bots labeled BOT and difficulty. Right: track preview, laps, contact, bot rules, region, private code when private. Bottom actions: Change Car, Ready/Unready, Leave Room; host also has Room Settings, Start, and Kick Player. Kick requires selecting a player then confirming; unavailable after Loading starts. Kicked guest cannot rejoin that same room for 10 minutes using the same identity; this is convenience moderation, not strong anti-abuse identity verification.

Host settings changes clear all human ready states. Car/paint changes clear only that player's ready state. Host transfers to longest-present connected human when leaving; ties use guest ID. If no humans remain, close room. UI clearly labels new host. Room name/visibility cannot change during a race. Private code has Copy and Show/Hide; hidden by default when returning from gameplay. Clipboard operations occur only on button press.

### 14.6 Loading and countdown

Loading: track postcard, track name, mode/laps, input icons, progress bar for local loading, ready-client count online, and one rotating hint chosen from a fixed list. Cancel returns to originating menu; online it leaves the room before roster lock if possible, otherwise disconnects with explanation. Do not show a false percentage for network waiting: use “Waiting for racers 5/6.” After 30 seconds, name excluded racers in a nonblocking notice to remaining players. Their slots become bots if bot fill is enabled, otherwise removed before grid creation. If all humans are removed, cancel the race.

Countdown text centered at x=50%, y=32%, 112 px high. No cinematics, track flyover, or input-blocking camera cuts after Grid begins. Race camera is stable before 3 appears.

### 14.7 Race HUD

| Region at 1080p | Content |
| --- | --- |
| Top left, x=96 y=54 | Position 1/8, lap 1/2; in Trial show TRIAL instead of position |
| Top center, x=960 y=54 | Race elapsed time; below it best-lap delta only in Trial |
| Top right, x=1824 y=54 | Current lap time, best lap; connectivity icon online |
| Bottom left, x=96 y=850 | 220×160 minimap, own arrow, rivals as numbered dots, start stripe |
| Bottom right, x=1660 y=850 | Large integer speed, mph/km/h label, small gear indicator, recover hold ring when used |
| Center, x=960 y=340 | Countdown, finish banner, wrong-way or recovery text; mutually exclusive by priority |

Banner priority: recovery > wrong way > finish/countdown > lap announcement. Announcements last 1.2 seconds; no stack of transient messages. Minimap is north-up using world -Z at top, with the whole route fitting inside 200×140 px. Own marker white arrow, others colored dots with numbers; ghost dashed cyan. Rival nameplates show within 80 m and line of sight, maximum four nearest, hidden within 8 m to avoid blocking close racing. At 720p nameplates may be disabled by default to preserve clarity. No leaderboard column permanently occupying the road view.

Display a network quality icon at RTT ≥150 ms or loss ≥3% over a rolling five-second window; severe state at RTT ≥250 ms or loss ≥8%. RTT is the mean of valid clock probes in that window. Loss is missing application snapshots among the latest five seconds (100 expected 20 Hz slots), including delivery stalls after a 100 ms jitter allowance. Count every valid decoded snapshot before rendering coalesces queued states; duplicates do not add delivery, and late arrivals fill known gaps. Wait for 20 delivery slots before using loss thresholds; reset the baseline on a new race or reconnect. Text appears only when focusing the pause-menu Network Status row. Do not repeatedly play warning sounds.

### 14.8 Pause menus

Offline race: Resume, Restart Race (not Cup), Settings, Controls, Quit to Menu. Cup: Resume, Settings, Controls, Save and Quit Cup. Time Trial: Resume, Restart Trial, Ghost On/Off, Settings, Quit to Menu. Online: Resume, Settings, Controls, Network Status, Leave Race. Leaving active play requires confirmation with exact consequence: “Leave this race? Your result will be DNF.” Offline Quit warns only when current race progress will be lost. Escape/Back cancels confirmation. No confirmation for ordinary menu navigation.

### 14.9 Results

Table: position, racer name, car, total time or DNF reason, best clean lap, gap to winner. Highlight local row with a border. Show New Personal Best only after the save succeeds. Trial results show time, previous-best delta, medal thresholds, medal icon, Retry, Change Track, Main Menu. Quick Race offers Retry, Change Event, Main Menu. Cup shows race points and cumulative table, Next Event or Cup Results, Save and Quit. Online offers Ready for Lobby and Leave Room with countdown to lobby. No autoplay advertising, currency shower, loot screen, or forced celebration sequence. A 0.8-second podium sound is sufficient.

### 14.10 Credits and quit

Credits sections: creators, third-party software, asset/music/font licenses, inspiration acknowledgement phrased without affiliation, and build information. Scroll manually; Back always available. Main-menu Quit exits immediately on desktop. Reset controls/settings/profile actions require typed or two-step confirmation as defined in settings; ordinary Quit does not.

## 15 Settings specification

Settings has tabs Display, Graphics, Audio, Controls, Accessibility, Gameplay, and Data. Changes apply immediately except display-mode changes, which use a 15-second Keep/Revert dialog. Closing the dialog or timeout reverts. A tab footer offers Restore This Tab and Back. Restore does not affect other tabs. Settings are local and never change room rules.

| Tab | Setting | Values and default |
| --- | --- | --- |
| Display | Window mode | Windowed, Borderless, Fullscreen; Borderless default |
| Display | Monitor / resolution | Enumerated supported modes; current monitor/native resolution default |
| Display | VSync | On default, Off |
| Display | Frame cap | 30, 60 default, 90, 120, 144, Unlimited |
| Display | UI scale | 90, 100 default, 110, 125, 150 percent |
| Display | Brightness | 0.80–1.20, step .05, default 1.00; does not change physics or fog |
| Graphics | Preset | Low, Medium default, High, Custom |
| Graphics | Render scale | 50–100%, step 10%, default 100%; HUD stays native |
| Graphics | Anti-aliasing | Off, 2× MSAA, 4× MSAA default |
| Graphics | Shadows | Off, Low default, High |
| Graphics | Draw distance | 400, 700 default, 1000 m; road collision and signs unaffected |
| Graphics | Effects | Off, Reduced, Full default |
| Graphics | Anisotropic filtering | 2×, 4× default, 8×, 16× |
| Graphics | Retro presentation | On default, 640×360 internal world render, letterboxed outside 16:9; UI stays native |
| Audio | Master / music / engine / effects / announcer | 0–100%, step 5; defaults 80/60/80/80/60 |
| Audio | Dynamic range | Standard default, Night; Night compresses loud peaks |
| Audio | Background audio | Off default, On |
| Controls | Remap driving/menu actions | Two bindings/action/device; reset defaults available |
| Controls | Stick deadzone | .05–.35, step .01; default .15 |
| Controls | Steering sensitivity | .75–1.25, step .05, default 1; multiplies axis before final clamp |
| Controls | Vibration | 0–100%, default 50%; zero fully disables |
| Controls | Prompt icons | Auto default, Xbox, PlayStation, Keyboard |
| Accessibility | Reduce Motion | Off default, On; enforces camera/transition changes in section 9 |
| Accessibility | High contrast UI | Off default, On; panels opaque, stronger outlines |
| Accessibility | Rival marker palette | Standard default, Deuteranopia, Protanopia, Tritanopia; numbers always retained |
| Accessibility | Announcer captions | On default, Off |
| Accessibility | Hold assistance | Off default, On; press Recover to arm, press it again to confirm, Back/Pause cancels; no deadline; same 30-tick (0.5-second) minimum |
| Gameplay | Speed units | mph default, km/h; distance follows miles/km |
| Gameplay | Camera | Far Chase default, Near Chase, Hood |
| Gameplay | Base vertical FOV | 55–85°, default 65°, step 1° |
| Gameplay | Dynamic FOV | On default, Off; forced off by Reduce Motion |
| Gameplay | Collision camera shake | 0–100%, default 50%; forced zero by Reduce Motion |
| Gameplay | Trial ghost | On default, Off |
| Gameplay | Rival nameplates | On default, Off |
| Gameplay | Driving hints | On default, Off; never changes simulation |
| Data | Display name | 3–16 Unicode grapheme clusters, NFC normalized; no controls/markup/newlines |
| Data | Export diagnostics | Save a sanitized local ZIP to user-selected path |
| Data | Reset personal records | Confirm twice; deletes records/ghosts/trophies, preserves settings and guest identity |
| Data | Reset all local data | Confirm twice; explains identity loss and active cup deletion |

Desktop resolution selects a client pixel size in Windowed mode, fitted inside the chosen monitor's work area. Borderless and Fullscreen preserve the OS desktop mode and use the selected supported size for world rendering before render scale; the HUD stays at native client resolution. Native follows actual client pixels. Other aspect ratios letterbox the world. Query available sizes through the OS on macOS, Windows and X11; when enumeration is unavailable (including Wayland), offer Native only. Monitor changes preview Native resolution in the same transaction. Revert restores actual window position/size as well as saved preferences.

Preset mapping: Low = 70% render scale, AA off, shadows off, 400 m distance, Reduced effects, 2× anisotropic; Medium = 100%, 4×, Low, 700 m, Full, 4×; High = 100%, 4×, High, 1000 m, Full, 16×. Changing one graphics value changes preset label to Custom. Retro presentation overrides world render resolution while enabled and restores prior render scale when disabled. Render scale otherwise multiplies viewport pixel dimensions with a floor of 320×180.

Remapping captures the next valid button/axis, ignores current opening input for 0.2 seconds, times out after 10 seconds, and permits cancellation. A conflicting binding offers Swap, Replace, Cancel. Essential Confirm/Back must retain at least one keyboard binding; prevent accidental complete lockout. Controller disconnect pauses offline, while online the game coasts with throttle zero and shows “Controller disconnected — keyboard available.” Keyboard fallback works immediately. Focus loss pauses offline; online input becomes zero throttle, zero steer, no handbrake, and normal rolling drag. Never keep a stuck accelerator after focus loss.

## 16 Accessibility requirements

All menus support keyboard/gamepad focus navigation with visible focus and logical reading order. Text can scale without truncating critical values. Captions duplicate every informational announcer line; audio-only information never determines race rules. Race positions use numbers as well as colors. No flashing effects above three flashes per second; countdown lights change once per second. No quick-time events or repeated-button mashing.

Driving assistance is limited to the common arcade handling model; there is no hidden auto-braking that changes records or online competitiveness. Steering sensitivity/deadzone and motion settings are presentation/input preferences, allowed in all modes. Driving School has unlimited retries and can be skipped. Menus expose accessible text labels through the engine UI facilities where available, but full screen-reader certification is not a launch claim; keyboard navigation, contrast, captions, and UI scaling must be verified on shipped platforms.

## 17 Audio direction

Music: human-authored heavy rock/metal recordings dedicated under CC0, with driving guitars, bass and drums. Seven loopable selections cover the menu and course music families; courses may share a selection. Preserve original recordings, composer credits, source URLs and license-page evidence in `assets/source/music/`. Do not synthesize procedural replacement songs. Keep the original arrangements and tempo, normalizing gain and applying only a short loop seam. No copyrighted soundalikes or recognizable borrowed melodies. Music must loop without a click or abrupt bar discontinuity. Pause offline ducks music by 8 dB and suspends engine movement; online overlay ducks by 4 dB but preserves race audio.

Each car has idle, low-load, high-load, and coast engine loops crossfaded by virtual RPM and throttle. Four virtual gears with upshift speed thresholds 12, 25, 40 m/s; downshift hysteresis 3 m/s. Gear changes only affect sound and tachometer, never acceleration. Pitch maps virtual RPM from 0.8× to 1.6×; shifts dip pitch for 0.10 seconds. Other car engines use distance attenuation to silence by 120 m, maximum seven audible rivals, panned spatially. Own engine stays centered with slight stereo width; no extreme Doppler on own car.

Effects: broadband asphalt tire scrub without pitched siren modulation, sand/grass rumble, light/heavy wall scrape, light bump, landing, recovery swoosh, countdown ticks/GO, lap/finish cue, UI move/confirm/back/error. Events have cooldowns to avoid machine-gun repetition: wall 0.15 seconds, bump 0.2 seconds per pair, landing 0.5 seconds. Mix voice/music lower by 3 dB for a countdown or finish cue, then restore over 0.3 seconds.

Announcer fixed English lines only: “Three”, “Two”, “One”, “Go”, “Final lap”, “Wrong way”, “New best time”, “Finish”. No taunts, player-name synthesis, incessant overtaking callouts, or dynamic voice chat. Wrong way voice plays once per continuous episode, at most once every 10 seconds. Announcer volume zero does not hide captions. Race announcer captions appear only during active driving; pause menus and their settings pages suppress them so a live GO line cannot cover navigation. Results retain saved-record captions. Master output must not clip under eight engines plus impacts; validate true peak ≤-1 dBFS on captured worst-case mix.

Gamepad vibration: engine vibration none; skid weak motor up to 0.15 while slipping; collision strong motor up to 0.4 for 0.12 seconds; landing up to 0.3 for 0.15 seconds. Multiply by user setting. Unsupported devices simply omit vibration.

## 18 Opponent AI

Bots use exactly the same car controller, caps, collision shape, and recovery rules as humans. Server computes their inputs at 60 Hz. Race recovery uses the shared rank-preserving rule in §5.4. Rubberbanding adjusts only planned AI pace; no extra engine power, grip or wall immunity. Bot car roster cycles Comet, Switch, Needle, Sunset by slot index; paints cycle the shared palette. Names are fixed original callsigns: Sunny, Jet, Poppy, Ridge, Skipper, Dash, Cove; no fabricated human profiles.

The launch AI racing line is the canonical centerline sampled every 2 m. Store it in the shipped track bake; do not substitute a private racing-line optimizer. Bots may offset it only for passing as defined below. Human players can gain an advantage by choosing wider entries and tighter apexes. Compute signed curvature from successive horizontal tangent angles divided by sample distance; smooth curvature with a centered five-sample arithmetic mean before calculating target speeds.

Target corner speed = sqrt(G × 0.82 / max(abs(curvature), 0.0005)), clamped to [12, 0.96×V]. Apply four backward braking passes over the closed sampled line, visiting indices N-1 down to 0, setting each target to min(current target, sqrt(next_target² + 2×12×segment_length)); index N wraps to zero. Runtime look-ahead distance = clamp(8 + 0.45×speed, 12, 35) m. Steering error is signed angle between car forward and target point; input = clamp(error_degrees/30, -1, 1). Throttle = clamp((target_speed-speed)/6, 0, 1); brake = clamp((speed-target_speed)/6, 0, 1). Bots do not use handbrake at launch. They recover if speed stays below 2 m/s for four seconds while commanded throttle >0.7.

Difficulty changes the line target speed multiplier: Easy 0.78, Medium 0.90, Hard 1.00. In races with active humans, compare each bot to the nearest human in gate-bounded total race distance, including completed laps. Within 25 m, pace is unchanged. Over the next 200 m, smoothly ramp the multiplier to 1.14 for a trailing bot or 0.82 for a leading bot; clamp the result to the baked safe speed. Finished/DNF humans do not pull bots, and all-bot, Solo, Trial and School runs retain their base difficulty. Human car handling stays unchanged. It also changes input planning delay: 0.20, 0.10, 0.05 seconds, respectively. Hold the previous planned input between planning updates while the underlying car simulation still ticks at 60 Hz. No random reaction-time spikes. For a nearby car within 25 m ahead and ±3 m lateral, choose passing offset ±3 m toward the side with more room, with stable slot ID breaking equal gaps. Shift offset at ≤2 m/s; if neither side has 2.5 m clearance, reduce target speed to the lead car's speed minus 1 m/s until a gap opens. Obstacle avoidance never leaves the paved corridor. Car contact off still uses avoidance for believable driving. Both lead selection and passing-side clearance ignore rivals more than **2.5 m perpendicular to the current collision-surface plane**. Derive that plane from the current baked road edge and next centre sample, including grade, bank and launch-ramp height offsets. This separates traffic on bridge levels while retaining a lead car several metres higher along the same steep road; a world-Y cutoff is insufficient.

Validation: seven bots must complete all eight courses at all three difficulties for 20 seeds without a permanent stuck condition or missed gate. On flat single-car reference runs, Hard must be faster than Medium and Medium faster than Easy. Human testing should find Medium beatable after learning the course; the bounded rubberband above keeps separated racers in contention without exceeding the authored corner limits.

## 19 Multiplayer simulation and transport

### 19.1 Authority and cadence

All official online races run on dedicated authoritative Godot servers. Client sends inputs, never accepted position, lap, time, medal, or collision outcomes. Server owns simulation, progress, final results, room configuration, and roster. Offline modes run the same simulation locally with the network layer bypassed.

Simulation 60 Hz; client input packets 30 Hz carrying the newest six input frames; server full snapshots 20 Hz; clock sync ping 2 Hz; lobby reliable events on change plus heartbeat every 5 seconds. Each packet stays below 1200 payload bytes; full eight-car snapshots fit this budget by quantization. Reliable large payloads are not used during racing. No assets are downloaded over the racing socket. Simulation, content, and protocol versions must match exactly online.

ENet channels: 0 reliable ordered for connection/session/lobby/start/result/recovery events; 1 unreliable ordered for input batches; 2 unreliable ordered for snapshots; 3 unreliable for clock probes. Reliable event processing is idempotent by event ID. GO uses an authoritative future tick exactly 300 ticks after the server commits load completion, allowing two seconds Grid plus three seconds Countdown. Grid and Countdown derive from that common start schedule. Client clock changes do not alter the server's tick.

### 19.2 Input and snapshot contracts

Input frame fields: race ID, input sequence uint32, intended server tick uint32, steer signed int8, throttle uint8, brake uint8, button bitmask uint8. Bits: handbrake, recover-held. Camera/look-back/menu actions stay local. Normalize values to their defined ranges; reject malformed lengths, nonfinite conversions, unknown bits, and input for a different race. An acknowledgement identifies the last processed input sequence for each player.

Server validates monotonic sequences with uint32 wrap handling and an allowable tick window of 12 ticks past to 12 ticks future. Late frames do not rewind the server. Future valid frames are queued, oldest-first per intended tick; at most one input frame per player per simulation tick is applied. Missing input holds last steer/throttle/brake for at most six ticks, then neutralizes throttle/steer and releases handbrake. The server has a fixed three-tick input buffer; map client intended ticks to this delay through clock sync. Buffering may increase server response latency but never delays local prediction. Repeated old frames are ignored, not applied twice.

Snapshot header: race ID, server tick, content hash prefix, race phase, race timer, event sequence. Each car record: slot ID, position (signed centimeters relative to track origin), velocity (signed centimeters/s), yaw and yaw rate, ground normal, grounded flag, authoritative brake-lamp flag (brake >0.1 or handbrake held), filtered steer, drift phase and timer, recovery phase and timer, ghost expiry tick, last gate, completed laps, last input acknowledgement, contact/slip event flags, and finish status. Do not omit state required to replay the controller. Quantization maximum position error 0.01 m, angle error 0.02 degrees, velocity error 0.01 m/s. Encode signed ranges large enough for every course; overflow is a protocol error, never wraparound teleporting.

### 19.3 Prediction and reconciliation

Local car runs immediately at 60 Hz using the player's inputs and static track collision. Keep 180 ticks of input history. On authoritative snapshot, restore the acknowledged local state, replay unacknowledged inputs in order against static world and historical/forecast remote poses, and update the collision proxy immediately. Use each input's intended tick plus the fixed three-tick server input buffer as its contact timeline. Skip inputs whose simulation time has already elapsed on authority, even when their acknowledgement did not advance. Rendered car/camera apply a separate decaying correction offset with a 0.12-second half-life; never feed this visual offset into collision or checkpoint logic. Corrections over 3 m, recovery events, or missing history snap the rendered offset. Routine clear-road correction target ≤0.25 m at 100 ms RTT, ≤0.5 m at 150 ms RTT.

Active drivers see remote cars forecast onto their local predicted timeline, without the former 100 ms presentation delay. Use latest velocity and yaw rate, rotating grounded velocity with heading; apply airborne gravity, road support probes and static-world sweeps. Forecast at most nine fixed ticks (150 ms) beyond the newest snapshot, including the three-tick input lead, then freeze. Cache these bounded forecasts per snapshot/slot; retain at most 20 snapshots. Historical reconciliation interpolates position, velocity and shortest-path yaw, holding discrete flags until their snapshot tick. Recovery/teleport intervals hold their earlier pose and suppress speculative contact; recovery poses stay frozen until authority releases them. Do not expire ghost protection speculatively.

For fresh estimates, run the shared bounded car-pair solver only for pairs involving the local car, preserving slot order and existing ghost/finished/DNF/contact-off exclusions. Resolve before progress/safety, and repeat during input replay. Disposable remote proxies receive the other half of the speculative impulse/separation and supply the visible rival poses; received snapshots are never mutated or sent back as authority. Once estimates exceed the forecast horizon, suppress predicted collisions until fresh data arrives. Contact audio/effects continue to use deduplicated authoritative events. A finished driver's own car retains buffered spectator presentation. No global deterministic lockstep requirement and no assumption that floating-point physics matches bit-for-bit across ARM/x86. Unseen braking/steering and transport delay can still cause corrections; no server rewind or client-authoritative hits are introduced. The contact tests in section 30 decide release readiness.

### 19.4 Disconnects and reconnects

After no input/heartbeat for 3 seconds, display Reconnecting and let server bot control the car. Keep the player's slot and result identity for 20 seconds. Client retries at 1, 2, 4, then every 5 seconds until the deadline, using a short-lived reconnect token. Successful reconnect receives a full snapshot and returns control at a future tick 30 ticks ahead; show a 0.5-second “Back in control” cue. The bot remains in control until that tick. No teleport, restarted race, or duplicated roster slot. Time Trial is offline and unaffected.

An unexpected disconnect in Lobby reserves the same human seat and token for 20 seconds, clears Ready and resets the countdown. Host administration transfers to a connected human. Rejoining keeps identity/car/paint and requires Ready again; an explicit Leave releases the seat immediately. Expired lobby reservations are removed. A valid token may replace an apparently connected older transport during one-way packet loss, retiring the older transport before handing over the same identity.

After 20 seconds, mark the human DNF; bot may finish visually but cannot earn the human a finish or points. Rejoining that race is then denied; offer Return to Lobby after the current race. Host administration transfers after the host is disconnected for 3 seconds, but original host may rejoin as a normal racer. If the game server fails, the race is abandoned with “Server connection lost — race result not recorded.” Do not manufacture standings from partial client state.

Mobile suspension intentionally sends a best-effort Away notice and immediately enables bot control; it does not rely on that packet arriving. The same 20-second reservation applies. Do not run online physics or keep audio playing in background to prolong the reservation. Details of mobile lifecycle are in section 26.

### 19.5 Iroh code rooms and the shared rendezvous service

Owner-authorized implementation, 20 October 2026, superseding the earlier
documentation-only note. Online adds **Host by Code / Join by Code** using the
same `https://iroh-rendezvous.maccam912.workers.dev/v1/join-codes` service as
Mega Chamomile. Regional directory rooms and ENet Direct Connect remain available.

A code host runs the existing RoomServer authority in an isolated, non-rendering
physics viewport inside its foreground game. Its own predicted client connects
through Iroh like every other racer. Eight human seats, bot fill, race rules,
loading readiness, authority-owned results, rematches and the 20-second guest
reconnect reservation keep their existing application contracts. The host must
keep running; leaving, quitting or Android background suspension closes the room.
Host migration is not provided for these listen-hosted rooms.

Iroh carries the existing raw application channels directly, without nesting
ENet. Reliable events use QUIC streams; input, snapshots and telemetry use ordered
datagrams. The native unreliable budget is 1,024 bytes (current eight-car
snapshots are 743 bytes with protocol 7); reliable frames retain the 1,200-byte application bound.
Large non-racing events retain the existing bounded fragmentation. The locked
source-built extension covers Windows/Linux x86_64, universal macOS and Android
ARM64. Its application ALPN is `pacific-rush/iroh/1`; normal protocol/content
admission checks still apply. No gameplay or save format changes are required.

The discovery service exchanges four-character codes for endpoint IDs. Codes
expire after ten minutes, can be replaced with New Code, and are revoked when
the room closes. Replacement revokes the previous mapping without disconnecting
existing racers. The `session_id` binds discovery to `pacific-rush/<protocol>/<content-hash>`;
other games and incompatible versions are rejected before dialing. Host-held
revocation tokens remain in memory and never enter UI, saves or diagnostic logs.
Codes are casual discovery, not account authentication. Abrupt process death
leaves a mapping until its bounded expiry. Discovery does not allocate servers
or relay race traffic; Iroh separately uses its N0 address lookup and relay preset.

See [the implementation and validation runbook](docs/IROH.md) for the pinned
upstream, Android JNI setup, build commands and exact acceptance boundaries.

## 20 Online service and abuse boundaries

### 20.1 Service structure

Use a small Go HTTP service for guest sessions, room directory, room allocation, and join tickets. Caddy terminates HTTPS. Each region runs this service plus a pool of headless Godot race workers, one room per process, eight human seats maximum. Use a single regional SQLite database for guest metadata, temporary room reservations, and service events; race frames and input streams are memory-only. Official regions share protocol/build versions; regional guest verification uses the same configured public verification key. A self-hosted development instance may use its own signing keys and Direct Connect.

Guest identity is a random UUID with a 256-bit secret created locally on first online use; store the secret in OS-protected storage where available and never in diagnostics. Register over HTTPS and receive a short-lived bearer session token (one hour). Reauthenticate using a nonce challenge and HMAC secret response over HTTPS. No email, password, personal profile, cross-device save, or recovery support. Resetting all local data loses that guest identity. Display names are not unique and are not trusted identity.

Registration transmits the secret only over HTTPS; server stores it encrypted at rest with a deployment key outside the database. Authentication nonces are cryptographically random, single-use, bound to guest ID, and expire in 60 seconds. Session/reconnect tokens are cryptographically random and checked in constant time. Native platform adapters provide secure storage where the engine alone does not; never embed a production signing/encryption key in a client build.

Launch APIs, JSON over HTTPS: `POST /v1/guests`, `POST /v1/auth/challenge`, `POST /v1/auth/session`, `GET /v1/regions`, `GET /v1/rooms`, `POST /v1/rooms`, `POST /v1/rooms/{id}/join`, `POST /v1/rooms/code/join`, `POST /v1/rooms/{id}/leave`, `GET /healthz`, `GET /readyz`. Guest registration/auth requests have no bearer token; other mutations require it. Room creation body contains the enumerated rules only; server rejects unknown rule values. Join returns worker address/UDP port, signed ticket, expiry, and protocol/content versions. Tickets bind guest ID, room ID, worker ID, build compatibility, expiry ≤60 seconds, and a single-use nonce. Room workers validate signatures and nonce before spawning a racer. Reservation consumes a human seat for 15 seconds, preventing simultaneous joins exceeding eight.

Worker status and allocation control use an authenticated local/private interface, never the public game port. The worker owns actual race state; directory entries are advertisements. Workers heartbeat every 5 seconds; after 15 seconds missing, hide room and reject new joins. Room creation waits at most 10 seconds for worker readiness before returning a retryable capacity error. Return 409 for full/started/incompatible room, 429 for rate limiting with Retry-After, and 503 for region capacity. User-facing text never displays raw traces.

Direct Connect supports a separately configured self-hosted worker in `direct_guest` mode, which accepts a protocol/content-compatible guest name and creates an ephemeral server identity without contacting the directory. It does not receive or request the player's official guest secret. Optional private code is configured by that server operator and checked before joining. Its reconnect token is limited to that worker/race. Official directory-managed workers use `ticket_required` mode and cannot be downgraded by a client packet; Direct Connect to one still requires an official join ticket. Show “Community server” on direct-guest lobbies. This is the explicit fallback when the official directory is unavailable.

### 20.2 Rate limits and validation

Per guest: room creation 3/minute and 10/hour; join attempts 20/minute; name changes 5/hour. Per IP: guest registration 20/hour and API requests 120/minute, with operator override for shared test networks. Room-code lookup returns one generic failure; no directory access for private rooms. Worker accepts at most 120 input packets/s/client and a 64 KB/s sustained inbound budget, disconnecting a sustained offender after 5 seconds. Clamp names by grapheme count and total UTF-8 byte length ≤96; escape for all UI/log contexts. Clients cannot supply server paths, script names, resource URLs, or executable payloads.

No free-form chat, uploads, or public leaderboards. Room host can kick in lobby; operators can ban a guest ID or rate-limit an abusive address through an authenticated admin CLI. Public game UI has no admin console. Guest identity is intentionally weak against reinstall evasion; do not market ranked competitive integrity. Server authority prevents ordinary fabricated speed/lap packets, but there is no kernel anti-cheat.

### 20.3 Privacy and operations

Retain operational logs seven days; rotate daily with 100 MB/process ceiling. Logs contain build, room ID, timing, error codes, and pseudonymous guest ID, never guest secrets, bearer/join/reconnect tokens, full input history, or clipboard contents. IP addresses used for rate limits expire after 24 hours unless an operator explicitly creates an abuse block. No advertising or third-party analytics SDK. Local diagnostics export requires user action and strips network addresses/tokens by default. Do not upload crash dumps automatically.

Do not assume ENet encrypts the racing traffic. It carries gameplay inputs and public racer data, not identity secrets; authorization travels via expiring signed tickets. Display names and gameplay state may be visible to network observers. HTTPS protects account/session/directory operations. If confidential racing transport becomes a requirement, it is a separate protocol/security revision.

## 21 Persistence and data formats

Store under the engine's platform-appropriate user-data directory. Required files: `settings.json`, `profile.json`, `records.json`, `cup.json` when active, `suspended_race.json` for mobile offline lifecycle recovery, `ghosts/{track_id}/{car_id}/{content_hash}.bin`, and a rotating diagnostic log. Each JSON file has schema_version, saved_at_utc, and payload. Use temporary file → fsync where available → atomic replacement; keep one last-known-good `.bak`. On malformed primary data, attempt backup; if both fail, preserve corrupt files with a timestamp and restore defaults for that component only. Show a one-time notice. A records error must not erase settings or identity.

Settings include platform-specific display/touch settings; never copy invalid desktop resolutions onto mobile. Profile contains display name, selected car/paint, tutorial exercise completion, aggregate completed race count/distance, trophies, and guest identity reference; secrets are stored separately. Records key = mode + track ID + car ID + content hash. Best times replace only on strictly lower valid time. Ties preserve original record and ghost. Race commits use unique race UUID to prevent duplicate stats on reconnect/reopening results. Stats count distance actually driven during eligible racing, excluding recovery teleport distance and menus.

Cup file contains championship ID, seed, difficulty/rules, car, full fixed bot roster, completed results, next event index, and content hash. If incompatible after update, preserve file, disable Continue, and explain “This cup uses an older game version. Start a new cup.” No silent conversion of results to changed handling. A save migration must have golden fixtures for every supported schema; unsupported future schema opens read-only and offers backup/reset, never overwrites automatically.

Ghost format: magic PRGH, format version uint16, content hash, track/car IDs, total time, 20 Hz quantized position/yaw samples, final exact finish sample, and checksum. Store transform playback, not a promise of cross-platform deterministic input replay. Interpolate ghost samples; no simulation. Maximum 2 MB per ghost and one best per car/track/current content version; keep previous-version records as an archive without loading their ghosts in incompatible races. Cap archived ghost storage at 100 MB, deleting oldest incompatible ghost binaries only after notice; preserve time records. There is no upload or download of ghosts.

## 22 Technical stack and architecture

### 22.1 Chosen stack

| Component | Required choice |
| --- | --- |
| Game engine | Godot 4 Standard, typed GDScript; baseline 4.6.3 stable with matching export templates |
| Renderer | Compatibility renderer for the entire launch game; no feature requiring Forward+ |
| Static collision | Godot Physics 3D queries with explicitly selected backend; custom kinematic vehicles |
| Simulation | Shared typed GDScript library, 60 Hz, no scene/UI/network side effects inside vehicle step |
| Realtime transport | Godot ENetMultiplayerPeer over UDP, dedicated authoritative servers |
| Directory / allocator | Go standard-library HTTP server, SQLite via a pinned supported driver, Caddy HTTPS proxy |
| Server packaging | Linux x86-64 headless Godot export; OCI image; one process per room |
| Art | Blender source files; glTF 2.0 exports; PNG/WebP textures; Ogg Vorbis audio |
| Data | Typed Godot Resources for content; JSON for local saves/service API; explicit binary race packets |
| Tests | Headless GDScript test harness, Python integration/geometry scripts, Go tests for service |
| CI | GitHub Actions or equivalent reproducible CI; platform export jobs and network integration suite |

Godot 4.6.3 is a reproducible baseline, not a claim that it is the newest release. Before first production export, verify mobile exporter/toolchain compatibility and security maintenance; any engine patch/minor change requires a recorded toolchain change and full compatibility tests. Do not independently upgrade one client platform or server. Pin exact engine binary/template checksums, Blender version, Go patch/driver module checksums, Caddy image digest, Python version, Android SDK/NDK/JDK, and macOS signing-tool versions in `tools/toolchain.lock` at milestone M0. Toolchain patch choices do not change game rules but must be identical in CI and contributor instructions. Android store target requirements are rechecked against official platform documentation at submission rather than frozen from this document's date.

Godot's ENet peer provides UDP networking, and dedicated export supports headless execution and stripped visuals. Neither supplies the prediction, race security, or reconciliation specified here. Engine source references: [ENetMultiplayerPeer](https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html), [dedicated server exports](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html), [release policy](https://docs.godotengine.org/en/stable/about/release_policy.html). These sources establish engine capabilities; the game's algorithms and budgets are design decisions.

### 22.2 Module boundaries

Proposed source layout: `game/core/` for vehicle/race/AI/progress pure logic; `game/content/` for car/track resources and baked routes; `game/world/` for collision/render scenes; `game/net/` for codecs/clock/prediction/transport; `game/ui/` for menus/HUD; `game/platform/` for lifecycle/storage/touch/haptics; `game/audio/`; `game/server/` for headless room entrypoint; `services/directory/`; `assets/source/`; `assets/exported/`; `tests/`; `tools/`; `docs/`.

Vehicle simulation consumes VehicleState + InputFrame + SurfaceQuery results and returns updated state plus event list. Race simulation consumes states/events and returns progress/results; it does not read HUD nodes. World query adapter is injected, enabling flat-plane fixtures. Client presentation consumes snapshots/events and cannot award results. UI sends intentions through a session controller, never mutates simulation arrays directly. Offline and server use the same RaceSession API. Servers must start without renderer, sound device, font loading, or touch/UI scene creation.

All gameplay data have stable lowercase IDs and explicit versions. `build.json` includes app semantic version, increasing build number, Git commit, engine version/checksum, protocol version, save schema, content hash, and target platform. Content hash covers car parameters, track collision/bakes, gates, AI line, and race rules; cosmetic-only assets have a separate asset hash. Online compatibility requires protocol and gameplay content hash equality, not identical platform binaries.

Random behavior uses seeded PCG32 with seed stored in race metadata. No global random calls inside simulation. Avoid wall-clock time in rules; all durations become integer ticks, with sub-tick crossing interpolation only for finish timing. On a late simulation frame, execute accumulated fixed steps up to six per rendered frame; never enlarge dt. If backlog persists, drop rendered frames/quality, not physics steps. Server overload is detected and reported, not disguised by time dilation.

### 22.3 Minimum shared content schema

CarDefinition: id, display_name_key, mesh_id, top_speed, acceleration, grip, turn_factor, default_paint, audio_profile_id. TrackDefinition: id, display_name_key, ordered_control_points, width_intervals, shoulder_intervals, surface_intervals, bank_intervals, ramp_markers, landmark_specs, environment_id, baked_route_id, collision_id, length, start_sample, gate_list, recovery_points, AI_line, thumbnail_id, minimap_id, content_hash. RaceRules: mode, lap_count, bot_fill, bot_difficulty, contact_enabled, grace_ticks, hard_limit_ticks. All fields have schema validation; missing required values fail import/build, not silently default at runtime.

`surface_intervals` are sorted nonoverlapping shoulder overrides in original base-curve u, each `{start, end, surface}` with 0 ≤ start < end ≤ 1 and a half-open [start,end) interval. Paving remains asphalt. Content version 4 includes the Summit sand override [.70,.90); protocol 5 uses state flag bit 7 for the authoritative brake lamp, with no packet-size increase. Ground-query/collision and car/track adapters participate in the gameplay compatibility hash. Older records and ghosts stay archived; incompatible cups stay preserved with Continue disabled.

No plugin is required for basic driving, progress, input, saves, or networking. A third-party convenience plugin may be added only with pinned source, license, platform checks, and documented ownership. Keep the code handoff buildable without a contributor's personal cloud account.

## 23 Performance budgets

Targets are requirements to measure, not established hardware results. Desktop minimum test class: four CPU cores, 8 GB RAM, GTX 1050 Ti / comparable Vulkan-or-OpenGL-capable GPU; macOS Apple M1 8 GB plus one supported Intel Mac for compatibility. Desktop target 1080p Medium at sustained 60 fps, p95 frame time ≤20 ms, p99 ≤33 ms during an eight-car race. If an Intel Mac cannot reach this, it must reach 720p Low at sustained 30 fps and disclose that tier. Desktop RAM peak ≤2 GB, VRAM ≤1 GB, installed assets ≤1.5 GB.

Mobile baseline targets: Android Snapdragon 778G-class/6 GB device, 60 fps at mobile default render settings for a 15-minute session without severe thermal throttling; 30 fps Quality/Battery mode remains supported. Test one lower-tier Android 4 GB device at 30 fps Low; it is a compatibility tier, not the 60 fps baseline. Mobile RAM peak ≤1 GB on baseline devices and ≤750 MB Low; install payload target ≤1 GB; initial offline launch must not require a content download. Minimum OS contract is Android 10, subject to exporter verification at M0; store target SDK is distinct from minimum OS.

One eight-car room: p95 server tick ≤5 ms, p99 ≤10 ms on a documented two-vCPU x86-64 host; resident memory ≤256 MB stripped export; per-client downstream target ≤40 KB/s and upstream ≤10 KB/s excluding handshake; measure actual wire traffic. CI should not assume nominal cloud vCPU performance equals physical cores. Capacity allocator reserves headroom and refuses new rooms before p95 tick rises above 10 ms. A worker exceeding 16.67 ms for 5% of ticks over 30 seconds raises an operator alert.

Loading targets after installation: cold app-to-menu ≤8 seconds desktop/12 seconds mobile; track load ≤8/12 seconds; same-track retry ≤3 seconds. No blocking shader compilation during Racing; warm required materials/effects in Loading. On mobile, cap texture sizes through import presets, use low LOD distances, and disable unnecessary overdraw rather than deleting readable signs or changing road geometry.

## 24 Failure behavior and diagnostics

Every recoverable error has a short explanation, Retry when meaningful, and Back/Offline fallback. Never strand the player behind a spinner. Asset mismatch blocks online joining before loading. Disk-full/save failure retains current in-memory session, shows “Couldn't save — free space and retry,” and offers Retry Save from results; it must not say New Best Saved. Local race can continue without saving after explicit dismissal. Interrupted atomic save restores backup on next launch.

Unsupported graphics context shows a plain startup error with required platform information and a diagnostics path; do not open a black window silently. Input device changes do not crash or change race physics. A lost mobile audio focus event mutes/ducks per platform policy and does not change driving state. Network switching Wi-Fi↔cellular uses reconnect behavior. Server version upgrade rejects old clients with “Update required” and a version value, without downloading executables automatically.

Developer overlay, disabled in release UI unless launched with a diagnostic flag: fps/frame time, tick backlog, car speed/slip/yaw, grounded probes, gate index, correction distance, RTT/loss, network byte rate. No privileged server controls in client builds. Diagnostic export includes logs, build metadata, platform capabilities, sanitized settings, and last 60 seconds of numerical performance aggregates; excludes tokens, personal paths, room codes, raw IPs, and entire user files. Raw logs remain inspectable locally. Bug-report workflow asks for export and reproduction steps, never secrets.

## 25 Deployment and delivery

Ship native client artifacts for every required platform, plus headless Linux server image and service image. Windows/Linux ZIPs include executable, PCK, licenses, and build.json; macOS is a signed/notarized app bundle in a DMG/ZIP for public distribution; Android includes signed APK for direct testing and AAB for store submission. Missing signing accounts can block distribution but not source implementation or simulator work; report that boundary explicitly. Do not call a simulator screenshot a physical-device test.

Initial distribution default is free, with no payment code or commerce integration. Store-facing art includes an original square icon showing a coral coupe beneath a cream sunrise arc on turquoise, plus mobile adaptive icon layers, desktop icon sizes, six gameplay screenshots per platform family, and a short factual description matching shipped features. Final publisher identity, title clearance, price changes, age-rating submission, privacy notice, support contact, and storefront publication require owner-supplied business details; do not invent them. Online data deletion requests must have an operator path keyed by a guest's authenticated session even though there is no email account.

Provide container definitions, region config example with secrets omitted, health checks, database migration/backup commands, firewall documentation for HTTPS and assigned UDP port range, and operator runbook. Example race UDP range 27020–27119 per host, one port per worker. Workers never share a UDP port. Directory HTTPS is 443. Game clients initiate outbound connections; players do not port-forward. Direct Connect to a user-hosted server requires the operator to expose its UDP port, explained in server documentation.

Deploy compatible new workers alongside old ones. Stop assigning new rooms to old content versions, allow active races up to 10 minutes to finish, then retire them. Never restart every worker in the middle of a rollout. Directory advertises supported build/content versions and regions. SQLite backup occurs daily; restore test monthly for operated production service. No scaling promise beyond measured host capacity. Service outage does not prevent offline launch, local records, garage, or Driving School.

Release package includes checksums, changelog, known issues, source revision, automated test report, desktop smoke evidence, physical Android evidence, and hosted cross-play test evidence as separate statuses. Source handoff contains build instructions for a clean machine and no personal credentials. A release is complete only when all required artifacts and validation gates pass; a successful local export alone is not release completion.

## 26 Android support and touch controls

Android mobile support is a first-release requirement, with the same four cars, eight tracks, race modes, physics, bots, records, and online rooms as desktop. No separate simplified mobile courses or altered grip. Android players may race desktop players in the same room. Input method is not a matchmaking filter because launch has no ranked mode. Offline modes work after installation in airplane mode. No ads, in-app purchases, energy timers, or mandatory mobile account SDKs.

### 26.1 Orientation and responsive layout

Landscape left and landscape right are supported on phones/tablets. Portrait racing is not supported. On initial portrait launch, show a simple Rotate Device screen; enter the menu once landscape is available. Respect OS rotation lock when possible; if the OS keeps a landscape app orientation, use that valid landscape viewport rather than repeatedly prompting. Switching between landscape orientations rebuilds safe areas and cancels active touches without simulating extra presses. Offline pause during orientation transition; online neutral input until fresh touches arrive, with a brief touch-control reentry cue.

Use the platform's safe rectangle excluding notches, camera cutouts, rounded corners, home indicator, and system gesture margins. Mobile layout coordinates below are normalized within that rectangle, not the full physical display. Touch controls stay at least 16 logical points inside the safe rectangle, with primary control centers at least 64 points from its edge. Logical point here means Android dp-equivalent derived from platform display scale, not raw device pixels. Buttons minimum 48×48 logical points; primary driving controls minimum 72×72; hit regions may exceed artwork by 8 points without overlapping another control. Text minimum 16 logical points, primary buttons 20, racing speed 36.

Phones use two-column track cards and a vertical list for car stats; tablets retain the desktop card grid when there is room. Lists scroll by drag, with no hover requirement. Native keyboard appears for names/codes/address entry and must not cover Confirm/Back. Disable autocorrect and capitalization for codes/addresses. Android Back maps to menu Back or Pause during gameplay, never quits a live race without the normal confirmation. Every Android submenu also has a visible Back button. Main Menu omits Quit on Android; the OS controls app exit.

### 26.2 Default driving layout

Touch default is **steering pad with automatic acceleration**, chosen to keep normal driving to two thumbs. Auto acceleration is an input convenience, not extra engine power. It generates throttle=1 while actively racing and input focus is present, except while brake/reverse is held, during recovery, or during the resume safety countdown. The same optional Auto Accelerate setting is available on desktop, default off there; it never changes car statistics or record categories. It never engages in menus/Grid/Countdown or while the app is backgrounded. Handbrake does not cancel auto throttle, permitting throttle-on slides.

| Control | Center in safe rectangle | Size | Behavior |
| --- | --- | --- | --- |
| Steering pad | x=.18, y=.78 | 180×100 logical points | Fixed horizontal analog slider, ±70-point travel, spring to zero on release |
| Brake / Reverse | x=.83, y=.80 | 88×88 points | Full brake while held; same stop/reverse timing as all other inputs |
| Handbrake | x=.91, y=.59 | 72×72 points | Hold to slide, normal drift thresholds |
| Recover | x=.72, y=.59 | 56×56 points | Same 0.5-second hold or accessible confirmation |
| Camera | x=.58, y=.92 | 48×48 points | Tap cycles cameras |
| Look Back | x=.47, y=.92 | 48×48 points | Hold looks backward; release restores |
| Pause | x=.95, y=.08 | 48×48 points | Opens pause overlay |

Steering pad is fixed, not floating: touching anywhere in its active rectangle captures that finger and sets steer from absolute displacement relative to center, clamped to ±1. Deadzone is 8 points at center, with the remaining 62 points remapped to full magnitude. Vertical motion does not affect steering. Touch applies the common sensitivity and steering filtering, but not the gamepad radial deadzone/exponent; its linear slider is intentional. No tilt/accelerometer permissions.

When Auto Accelerate is off, add an 88×88 throttle button at x=.90,y=.81 and move Brake to x=.75,y=.81; handbrake moves to x=.90,y=.57 and Recover to x=.74,y=.57. Touch throttle/brake are digital, unless a gamepad is active. This manual layout allows three-finger combinations but is optional. The default automatic layout must allow steering+brake and steering+handbrake with two thumbs without hand repositioning across the screen.

For small safe rectangles, calculate sizes from the specified minimums, then move centers inward to prevent overlap and keep bottom controls above the home-indicator margin. If no legal placement fits, use steering pad 150×90, primary pedals 72×72, secondary buttons 48×48 and move camera/look-back above the bottom center HUD; never shrink below these minima. Phones shorter than 320 logical points in landscape safe height are unsupported and should receive an explanation before entering a race.

### 26.3 Multitouch and ownership

Track each pointer ID independently. A touch captured by steering remains steering until release/cancel even if dragged outside its artwork. Pedal/handbrake finger remains captured within its hit rectangle plus 24-point release margin; outside that margin the action releases, and reentry resumes only while the same pointer is still captured. One pointer cannot trigger two controls. Another finger can operate a different control concurrently. Touch-down on scenery never steers. Menu taps and race touches use separate contexts; transitioning screens clears all captures.

Touch cancel, focus loss, OS gesture, pause entry, controller takeover, recovery transition, or orientation change releases every active action immediately. After returning to offline gameplay, show a 3,2,1 resume countdown with the world frozen; automatic acceleration resumes at GO. Online overlay closing does not pause the race or grant a three-second countdown; show a 0.5-second “Controls active” cue and resume auto throttle only after a fresh touch on the steering pad or throttle. This prevents an unattended car accelerating when a notification is dismissed.

Gamepad on mobile is fully supported. Last active input device determines prompt artwork. Once gamepad axis exceeds 0.2 or a driving button is pressed, suppress touch driving and fade its controls after two seconds; touch on a control reclaims touch input and neutralizes gamepad driving until it moves again. Do not sum steering axes from different devices. Device switching never toggles Auto Accelerate unexpectedly: each input profile stores its own preference. Keyboard on a tablet may use desktop bindings without hiding touch until keyboard input occurs.

### 26.4 Mobile HUD and settings overrides

On touch, move the minimap to top left below position, maximum 130×90 points; speed to bottom center above camera/look-back buttons; remove the gear indicator; keep timer at top center and lap at top right, leaving Pause unobstructed. Nameplates default off on phones, on for tablets. Primary controls are cream outlines with 30% dark fill, becoming 70% fill while pressed; preserve steering knob visibility over bright sand. Controls must not cover the road vanishing point or the player's car above the lower quarter.

Mobile adds a Touch tab after Controls: Auto Accelerate on default; Steering Style Slider default or Left/Right Buttons; Button Size 85–130% default 100 with minima enforced; Opacity 25–100% default 60; Left-Handed Layout off default; Haptics off default; Edit Layout; Restore Layout. Left/Right Buttons replace the slider with two 72-point buttons centered at x=.11 and .25,y=.78; simultaneous press gives zero steer. Left-Handed Layout mirrors steering and pedal clusters horizontally, while Pause and centered camera controls stay fixed. It does not invert steering direction.

Edit Layout opens a frozen sample track with draggable control outlines, snapping to an 8-point grid. Store normalized center positions per orientation class and phone/tablet class. Enforce safe area, minimum sizes, and nonoverlapping hit targets on Save. Cancel restores the previous layout. Preview provides a noncompetitive 30-second practice loop, returning to the editor afterward. Layout changes are unavailable during an online race; the settings row explains “Change this in the lobby.” OS safe-area changes revalidate and minimally clamp positions, showing a one-time reset notice if the old layout cannot fit.

Mobile Display hides monitor, window mode, resolution, and VSync options; frame cap offers 30 or 60 only, default 60 on baseline devices. Default Mobile graphics = 80% render scale, 2× MSAA, shadows Low, draw distance 400 m, effects Reduced, anisotropic 2×. A Battery preset sets 30 fps, 70% render scale, shadows Off, effects Reduced. High remains selectable but carries no promise above device budget. No automatic gameplay speed reduction under thermal pressure. Adaptive resolution option defaults on: after frame time exceeds target×1.15 for two seconds, lower scale by 10 points to minimum 60%; after ten seconds below target×0.85, raise one step up to selected scale. Do not change AA or effect behavior midcorner. HUD stays at native resolution.

Haptics use short platform effects where available: one light pulse on UI confirm, one medium pulse ≤50 ms on collision, cooldown 250 ms. No constant engine vibration or haptic pulses per frame. Disabled by default to avoid battery drain and sensory distraction. Gamepad vibration remains its separate setting.

### 26.5 Lifecycle, connectivity, and saves

Offline backgrounding immediately pauses and checkpoints resumable race state atomically. Save car/bot states, progress, timer, seed, race phase, and content version, except Time Trial: a trial interrupted by process termination restarts, while an ordinary background/resume may continue but marks that run invalid for records. On returning to a surviving process, show Resume with the three-second countdown. On cold restart after OS termination, offer Resume Offline Race or Discard; never auto-resume into motion. Online has no local race-state resurrection; reconnect through the server reservation rules.

Save settings/selection after each confirmed change and cup/results at commit time, not only on app exit. Assume the OS may kill the process without a final callback. If memory pressure occurs, discard menu previews/cached inactive track assets, not required collision or current race state. Never open a second renderer/scene to make a thumbnail while racing.

On phone call/audio interruption, follow OS audio focus and release touches; offline pause, online bot takeover through Away/reconnect flow. After >20 seconds away online, the player is DNF and returns to the lobby flow. Wi-Fi↔cellular transitions attempt reconnect without duplicate identity or slot. Show a one-time “Online races use mobile data” notice when first starting on cellular, with Continue and Cancel, remembered locally; do not warn repeatedly. Do not request microphone, location, contacts, camera, photo-library, or broad storage permissions. Diagnostics use the system share/save sheet; internet access and platform-required networking declarations are sufficient for normal play.

Keep display awake only during active foreground gameplay/loading; release keep-awake in menus after normal platform timeout policy. Respect OS audio mute/focus behavior. Test edge-swipe gestures and system navigation so touching controls does not routinely exit the app. Do not block OS emergency or accessibility gestures.

Godot export reference: [Android export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html). Android distribution requires the appropriate APK/AAB signing configuration. Engine export capability does not prove device performance, touch usability, or store approval.

## 27 Production milestones and work division

These milestones are dependencies and acceptance gates, not calendar estimates. Two implementers should divide by module ownership while sharing versioned contracts. One person may own simulation/network/server; the other content/presentation/UI/mobile. Both review changes to vehicle state, packets, track bakes, saves, and input mapping. If one person implements alone, the same gates still apply. Do not create parallel incompatible vehicle implementations.

| Milestone | Deliverable | Exit gate |
| --- | --- | --- |
| M0 Toolchain and contracts | Pinned build tools; blank desktop/Android exports; headless server startup; schemas; validated six route bakes | Clean-machine build instructions work; physical phone renders/input works; route constraints pass |
| M1 Driving slice | Comet, Palm Bay graybox, controls/camera/collision/recovery, touch default layout | Driving numeric fixtures pass; desktop and phone test laps; no network dependency |
| M2 Network risk | Two clients and dedicated server, prediction, gates, contact, reconnect | 150 ms RTT/3% loss tests pass; Android versus desktop race finishes consistently |
| M3 Complete race flow | Bots, all offline modes, online lobby/directory, settings/saves/results | All screen paths and state transitions work with placeholder art |
| M4 Content and style | Four cars, six final tracks, audio, UI style, ghost/medals/cup | Asset inventory complete; route hash stable; golden screenshots and complete races on every track |
| M5 Mobile and robustness | Phone/tablet layouts, lifecycle, thermal/quality tuning, service fault handling | Physical Android phone/tablet matrix, network switching, background/kill, save corruption tests pass |
| M6 Release | Signed packages, hosted regions, licenses, runbook, CI evidence | Full acceptance matrix, clean install/update, eight-player cross-play soak, all required artifacts |

M2 is deliberately before expensive scenery production because driving contact under latency is a major risk. A failed M2 blocks expanding content polish, not investigation. M1 touch feel is also a gate; mobile cannot be deferred until desktop controls are deeply embedded in UI assumptions.

## 28 Art and interaction reference captures

At M1 capture graybox reference videos before visual polish: Comet accelerating from rest; a 90-degree bend at 25/40/50 m/s; a short controlled slide; wall scrape; car bump; jump landing; touch braking/cornering. Use a visible input overlay only in developer recordings. Keep starting state, seed, camera, and build metadata with each capture. These become behavioral references for later tuning.

At M4 establish reference screenshots for each track at original u=.10,.35,.60,.85 using Near Chase, noon-equivalent exposure per track, Medium desktop preset, and no HUD; also capture Main Menu, car/track selection, lobby, racing HUD, settings, results, touch phone HUD, and tablet track selection. Reference resolution 1920×1080 desktop and actual named device resolutions for mobile. Screenshots document the implemented spec; they do not replace the numerical palette, geometry, and placement rules. Two independently made versions may differ in decorative brushwork but must preserve scene composition, named landmarks, road topology, vehicle silhouettes, and UI arrangement.

Do not use an AI-generated concept image as a measurable track collision/layout reference. If concept art is later commissioned, it must conform to these rules or cause an explicit revision. Final game assets require actual editable sources and licenses.

## 29 Test fixtures and build checks

Create a test-only flat 1000 m asphalt lane, a flat 80 m-radius circle, a 45 m-radius circle, a 5-degree slope, a static wall at 15-degree approach angle, a full-width jump fixture matching Pacific Summit, and a two-car contact lane. These are developer fixtures, not extra player-visible tracks. Every driving fixture uses explicit state/input arrays at 60 Hz and records distance, speed, yaw, slip, gate changes, and recovery events.

Automated content checks: required IDs unique; all references resolve; four car records and ten track records exist; route constraints pass; every gate has a safe recovery point; no spawn overlap; start line fits eight-car grid; road mesh/collision match; server exports retain collision/bakes; no required textures missing at any import preset; UI localization keys resolve; all asset licenses present; packets fit 1200 bytes; JSON schemas reject invalid values; no secrets in artifacts. Each check fails with the offending resource/field and a nonzero exit code.

Golden numeric tests use epsilon, not pixel identity or cross-platform bit identity. Reference runs on the same pinned build/platform must match final position within 0.02 m and finish time within one tick. Cross-platform offline runs of the same inputs must remain within 0.5 m after 60 seconds in static fixtures; if divergence exceeds that, investigate stability before relying on online correction. Online end results must agree exactly because they come from one server.

## 30 Acceptance matrix

Each row is required. Evidence records build, platform/device, settings, steps, observed metrics, and pass/fail. “Looks good” alone is not a pass for a numerical requirement.

| ID | Procedure | Required result |
| --- | --- | --- |
| DRIVE-01 | Comet flat launch, throttle 1 for 20 s | 0–100 km/h within 1.5–2.0 s; speed never above permitted cap; no lateral drift with steer 0 |
| DRIVE-02 | Brake from 100 km/h on flat asphalt | Stop in 18–26 m; no automatic reverse until 0.35 s stopped brake hold |
| DRIVE-03 | Constant steering at 25/40/50 m/s | Turn tightens at lower speed; repeatability tolerance met; no snapping or rollovers |
| DRIVE-04 | Sustained full-lock steering and 0.5 s handbrake turns, then release/countersteer | All four cars slide at speed without handbrake; sustained lock stays controlled; partial lock/parking/reverse/airborne cannot initiate drift; grip restoration completes in .40 s; no boost or hidden speed gain |
| DRIVE-05 | Scrape wall at 40 m/s, 15° approach | Forward motion retained; no repeated 4% per-tick damping; no wall penetration >.05 m |
| DRIVE-06 | Two-car bump at 10 m/s relative speed | Impulse bound honored; no angular flip; neither car pushed through world wall |
| DRIVE-07 | Ramp at 30/45/60/80/95 m/s; −15%, flat, +15% grades | Single launch trigger per lap; safe landing; no tunnel-through or repeated snap-launch |
| RACE-01 | Skip/reverse/recross gates | No false lap or finish; progress never jumps to neighboring route segment |
| RACE-02 | Same-tick finish pair | Sub-tick order used; exact tie resolves by slot; every client sees same order |
| RACE-03 | Finish then wait | 30 s grace and 600 s hard cap respected; remaining racers DNF appropriately |
| RACE-04 | Recover at every gate | Safe location, retained gate/lap state, zero velocity, ghost expiry rules; no forward progress exploit |
| AI-01 | Seven bots, all tracks/difficulties, 20 seeds | All complete without permanent stuck state; any recovery is logged; no missed gates |
| TRIAL-01 | Valid, invalid, tied, slower, faster runs | Only valid faster runs replace best/ghost; medal comparisons match formula |
| CUP-01 | Finish, quit, reload, abandon, tied points | Exact roster/points/order preserved; specified tiebreaks and resume semantics |
| NET-01 | Eight clients, 100 ms RTT, ±20 ms jitter, 1% random loss, ten races | No divergent standings; p95 own-car clear-road correction ≤.25 m; no stuck controls |
| NET-02 | Two clients, 150 ms RTT, ±30 ms jitter, 3% loss, 20 side/rear contacts | p95 clear-road correction ≤.5 m; p95 contact correction ≤1.5 m; no uncommanded flip or wall penetration |
| NET-03 | 250 ms RTT, 8% loss, 60 s | Quality indication; controllable local car; no crash/unbounded extrapolation; fairness not guaranteed at this degraded tier |
| NET-04 | Disconnect 5 s, reconnect, then disconnect 25 s | Same slot returns under 20 s; DNF after expiry; no duplicate result/identity |
| NET-05 | Concurrent final-seat joins; stale/forged/duplicate tickets; malformed inputs | Exactly eight seats max; invalid requests rejected; server remains healthy |
| NET-06 | Host leaves lobby/race; worker crashes; directory unavailable | Correct admin transfer; abandoned race has no invented result; offline modes remain usable |
| UI-01 | Complete all menu paths using only keyboard, then gamepad, then touch | No trapped focus, hover-only action, blocked confirmation, or lost selection |
| UI-02 | 720p, 1080p, ultrawide, 4:3, 150% UI; phone notch and tablet | No critical clipping; safe areas respected; readable labels and timers |
| SAVE-01 | Kill during save, corrupt primary, disk full, future schema | Backup/default recovery as specified; no unrelated data loss or false save message |
| MOBILE-01 | Two-thumb steer+brake and steer+drift for 10 races | All inputs register independently; zero stuck touches; no OS gesture routinely triggered |
| MOBILE-02 | Five simultaneous touches, pointer cancellation, layout edit, device switch | Correct ownership/release; no duplicate menu taps; legal layout restored |
| MOBILE-03 | Background 5/25 s, call interruption, orientation flip, OS kill | Correct pause/reconnect/DNF/resume; no acceleration without input reentry online |
| MOBILE-04 | Wi-Fi to cellular midrace and back | Reconnect within reservation if network permits; no duplicate slot; failure message otherwise |
| MOBILE-05 | Android + desktop mixed eight-car race | Identical rules/results; complete race and rematch across all clients |
| PERF-01 | 15-minute eight-car worst-track run on named baseline devices | Section 23 frame/memory/network budgets; no growth >5% after warm-up between minute 5 and 15 |
| AUDIO-01 | Eight engines, simultaneous impacts, captions and mute variants | No clipping; max -1 dBFS peak; cues readable without sound; no duplicated contact sounds |
| ACCESS-01 | Reduce Motion, high contrast, palette modes, 150% text | Specified motion removed; no missing gameplay information; no layout corruption |
| RELEASE-01 | Clean install, offline start, update preserving saves, uninstall/reinstall | Platform packages start; compatible saves migrate; identity-loss behavior is explained |

Network correction percentiles exclude deliberate recovery and server restart, but include ordinary driving and contact; tag those populations separately. A test may not hide large correction events by averaging them into mostly stationary samples. Capture at least 1,000 snapshot corrections for percentile claims. Physical-device tests must name OS/model and distinguish plugged-in performance from battery operation. Perform mobile thermal tests unplugged at a documented ambient temperature of 20–25°C.

## 31 Completion criteria and change control

The implementation handoff is complete when every launch feature is reachable, all named assets exist, all acceptance rows have evidence, every platform has a reproducible build, both official online regions work, and no known defect can lose a save, fabricate a race result, trap navigation, leave stuck input, or make a course impossible to finish. Cosmetic defects may remain only if listed with screenshots and explicitly accepted by the product owner.

First release may not silently omit mobile, substitute peer-hosted multiplayer, remove collision, replace six courses with one, or call unfinished menus “future work.” If scope must shrink, record an explicit product decision and revise the contract. Track geometry, handling values, medal thresholds, and protocol changes increment content/protocol versions as appropriate and include migration/compatibility notes.

For each later change, record: problem, exact changed rule/data, affected tests, compatibility impact, and screenshots/video when presentation changes. Keep this document as the authoritative behavior specification. Code comments and backlog cards cannot override it. Product-name clearance, developer signing accounts, hosting account/domain ownership, store metadata/rating forms, and final asset licensing are external release inputs; they do not authorize an implementer to invent unrelated game mechanics or skip implementation.

## 32 Handoff checklist

- Editable source project, server/service source, all authored assets, licenses, and toolchain lock.
- One command for local offline run; one command for local dedicated room plus two clients; documented mobile export/signing steps.
- Tested desktop packages, Android APK/AAB, Linux server and directory images.
- Versioned car/track/rules data, measured route lengths, baked checkpoints/recovery locations, input and packet schemas.
- Menu/HUD and mobile layout reference captures, driving reference videos, sanitized performance/network reports.
- Automated checks and acceptance evidence, failure/reconnect/save migration tests, operator runbook and known issues.
- A short README explaining where to change handling, add a track, adjust touch layout, run tests, and publish a compatible build.

No implementation or game assets are created by this design document itself. All target values remain requirements until validated in the actual build.


## Owner visual expansion direction — 19 October 2026

After the current validation repair, expand the course experience with stronger
route-shape variety instead of a family of ovals or kidney loops. Broaden the
track catalogue as practical, and give each environment distinct driving and
landmark sequences. Decorations must include visible rocks, logs, waterfalls and
other authored set pieces rather than relying mainly on trees. Retain the
approved mix of illustrated cards and substantial 3D geometry.

Revise the interface toward a nostalgic radical arcade presentation: bold techno
lettering, gloss, saturated accents and energetic panels/buttons. Preserve
required contrast, scalable text, visible focus, touch targets and reduced-motion
support. This owner direction supersedes the current clinical dark-panel visual
treatment. The original wordmark, custom display face and chrome are implemented;
their current source/native/emulator validation is recorded in docs/STATUS.md.
The owner specifically rejected the earlier tidy techno treatment as too modern:
the intended reference is loud late-1990s arcade cabinet graphics.

The owner also approves extending the decorations' dithered look into richer car
and pavement materials. Add styled paint/surface detail and wear while retaining
clear road edges, readable opponents, original assets and the established physics
contract. The original paint/glass/chrome and dry-asphalt shaders implement this
material revision; current evidence and remaining package boundaries are recorded
in docs/STATUS.md.

The content-6 scenery pass adds original procedural boulder clusters on ground courses, log piles on orchard/forest/mountain/quarry routes, waterfalls on Redwood/Summit/Quarry, and larger quarry bluffs. Sites clear the road and poster approach sightlines, reserve foliage clearings, and use independent spatial bounds and view-distance limits. These meshes have no driving collision. Skyline towers, bridge deck and pylons provide a distinct elevated city silhouette.

## Content 7 — long-course snapshot checkpoint correction

The first eight-course development snapshot exposed a legacy decoder bound of 40 checkpoints. Skyline Splice has 49 checkpoints and Quarry Switchback 65; valid late-race snapshots were rejected while reliable results could still arrive. Build 104 was cancelled before publication when the expanded eight-client fixture exposed the issue.

The decoder now derives its upper checkpoint index from the loaded catalog. Per-course guards in client snapshot application still reject indices outside the selected route. The signed-byte field and protocol-5 packet layout remain unchanged (727 bytes for eight cars); the baker rejects more than 128 checkpoint entries. This is content version 7 / protocol 5 / save schema 1. Course definitions/bakes, steering, traffic planning, car physics, race grace and wire/correction limits are unchanged. Prior content-4/5/6 fixtures stay frozen; their records/ghost/Cup/checkpoint bytes remain preserved with incompatible continuation disabled.

Acceptance now includes all 321 authored checkpoints in snapshot round-trips, final checkpoint receipt through direct and batched client paths, invalid checkpoint rejection, and eight real impaired clients on both bonus courses. Every client must observe snapshots reaching the final checkpoint section, finish, and agree with authoritative rows. A matching installed Android APK is checked separately against native clients.


## Content 8 — traffic remains on the correct road level

A deterministic Skyline crossing regression showed the content-7 planner choosing a passing offset for a car 180 m above it. Both lead selection and passing-side blockers now use the 2.5 m road-plane separation rule in §18. The road plane comes from shared collision geometry, including bank and ramp offsets; tests retain cars 4.8 m higher/lower along a 24% climb/descent and banked roads. Input planning cadence, lane clearance, stable slot tie breaks, following speed, car physics, route bakes, contact and recovery rules remain unchanged.

This is content version 8 / protocol 5 / save schema 1. Frozen content-4/5/6/7 components retain exact bytes; incompatible records, ghosts, Cups and in-progress races remain archived with continuation disabled. The content-7 fixture was captured from clean commit `7906385` before changing traffic logic, with a validated profile, synthetic record/ghost, fresh Cup and actual 600-tick eight-car Quarry checkpoint. Complete field races and remote release gates remain separate from the focused planner proof.


## Presentation follow-up — 20 October 2026

Skyline tower walls use original procedural window grids and static glass reflections, aligned in facade metres with floor bands; roof equipment and trim remain opaque solids. Ordered dither and derivative filtering keep distance detail stable. Opponent labels share the original arcade chrome/display-number face while retaining nickname/emoji support, color-palette identity, clipping, four-label limit, occlusion and High Contrast.

Graphics acceptance separates construction from GPU readiness. Its construction fixture allows max(60 seconds, (actual authored build steps + four frame allowance) × one second), recording each world's unit count, cap and measured duration. The independent 15-second two-frame/readback GPU deadline, Retry/Cancel/background and real ENet Loaded ordering remain. Reports retain partial course results and failure state; only full completion is successful. These construction fixture bounds do not change production loading or the performance budgets.

## Arcade course identities — 20 October 2026

The owner requests substantially different layouts and driving experiences in the
style of 1990s arcade racers. This section supersedes the original six coordinate
lists and their former common asphalt-only presentation. The current definitions
and canonical bakes are normative; `tools/author_arcade_tracks.py` reproduces the
six authored layouts. `tools/course_layout_preview.py` renders their actual maps
and elevation strips in `docs/evidence/arcade-tracks/layouts.svg`.

| Course | Driving identity |
| --- | --- |
| Palm Bay | 3.99 km broad coastal pentagon; 20 m highway, long straights and sweeping bends |
| Citrus Pass | 4.97 km orchard zigzag rally; 18 m clay road, alternating block cuts and two launches |
| Marina Lights | 5.27 km flat downtown block circuit; long boulevards, sharp braking corners, lit towers and purple night lighting |
| Redwood Run | 5.21 km forest dirt slalom; narrow 16 m road, linked reversals, 93 m height range and a timber launch |
| Sunstone Canyon | 5.08 km desert dirt stadium; long launch straight, broad sweepers, twisting infield and three jumps |
| Pacific Summit | 5.60 km mountain rollercoaster; 150 m height range, 20.5% maximum grade, three launches and 24 m landing zones |
| Skyline Splice | Retains its layered harbor figure eight and bridge launch |
| Quarry Switchback | Retains its chain of climbing hairpins |
| Spillway Sprint | Retains its three-lobed elevated reservoir knot |
| Caldera Crosscut | Retains its seven-crossing star geometry; now an alien volcanic moon with starfield, ringed planet, crystals and neon speed gates |

Authored street corners use centripetal Catmull–Rom interpolation so unequal
block lengths cannot create loops near corners. The original uniform option
remains for expansion geometry. Allow 16–64 controls; preserve 2 m samples,
28 m minimum radius, 24% maximum grade and safe separation/start checks.

`road_surface` selects asphalt or dirt independently of shoulder surface. Dirt
uses 0.78 grip and 1.2 m/s² extra drag above 12 m/s, with brown rutted gravel,
dust and the existing loose-surface rumble. It has no painted highway lanes.
AI braking curves use the same grip multiplier. Each course supports up to three
ramps; each fires once per lap, with the existing 7.2 m/s kick and 23-tick launch
lockout. The signed `jump_lap` byte now stores `lap*8 + consumed_ramp_bits`.
Protocol 6 adds dirt as surface byte 3 and defines that bitfield; the eight-car
snapshot remains 727 bytes. The shared development content version is 10 and
save schema remains 1. Preserve frozen content-4 through content-9 fixtures and
incompatible player records/ghosts/Cups/checkpoints byte-for-byte.

Acceptance includes actual main-road surface probes, every ramp launching and
landing on course collision, repeat-trigger suppression and next-lap rearming,
network round trips of dirt and all ramp bits, geometry diversity thresholds,
all-car trials, complete-field races, and native rendered review. Publication
and minimum-device/human feel checks remain distinct from local source evidence.


### Race pacing and recovery revision — content 11 / protocol 7

Race pacing and rank-preserving recovery in §§5.4 and 18 supersede the earlier
content-10 recovery and no-catch-up rules. Protocol 7 adds a centimetres/second
unsigned 16-bit rolling recovery speed per car, so local prediction releases the
fade with the same speed as authority. Eight-car snapshots are 743 bytes;
input packets and the 1,200-byte application limit are unchanged. Rank and
last-safe progress remain authority-only state, preserved at full precision in
offline archives. Save schema stays 1. Frozen content-10 and earlier player
records, ghosts, Cups and checkpoints remain preserved with incompatible
continuation disabled.


## Forty-course expansion (owner revision, 21 October 2026)

The playable roster contains forty courses. `docs/COURSE_ROSTER_40.md` specifies
the retained ten and thirty additions, including their route shapes, surfaces,
relief and landmark direction. `tools/author_expansion40.py` authors the new
canonical controls; the existing baker validates every route. New scenery uses
six original, untouched imagegen atlases plus a standalone blossom tree (52 alpha-bounded sprites), thirty
terrain exports and static themed 3D gates. Snow/wet/alien appearances retain the
existing asphalt/dirt physics. All forty courses are immediately available in
Quick Race, Trial and online selection; Coast Cup retains its six-event sequence.

Gameplay content advances to 12; protocol remains 7 because the wire format and
its dynamic track-index bounds already support the expanded roster. Save schema
remains 1. Frozen content-11 profile, record, ghost, Cup and active-race bytes are
preserved; incompatible continuation/comparison is disabled. New profiles default
to Far Chase and Retro presentation. Explicit saved preferences remain respected.

Road rendering partitions exact original triangles into local spatial chunks,
with exact positions/UVs, finite unit normals and no distance limit on the road. Pavement/markings
receive shadows; guardrails and elevated deck undersides cast them. Collision
continues using the original unsplit canonical meshes. This reduces whole-lap
triangle submission without changing driving physics.

Summit groups roadside instances by species in 256 m spatial cells instead of
80 m route intervals. Every instance keeps its exact world transform; dense
inward views submit fewer separate batches. Road chunks span 640 m to balance
triangle rejection against submission overhead. Native render evidence and its
limits are recorded in `docs/STATUS.md`.

### Expansion route and landscape revision, 21 October 2026

Content 13 replaces the thirty additions' route geometry while retaining the
first ten definitions and bakes. Protocol 7 and save schema 1 remain unchanged.
Content-12 profile, record, ghost, Cup and suspended-race bytes are frozen and
preserved; incompatible comparison and continuation remain disabled.

Sixteen additions use individually drawn continuous spline curves. The remaining
street, freight and utility courses use circular corner fillets with individually
chosen radii and block lengths. Laps range from 3.20 km to 10.58 km; nearly straight
sections occupy 8–74 percent of a lap, with longest straights from 136 m to 2,688 m.
The shared minimum 28 m radius, maximum 24 percent grade, separation and standing
grid requirements still apply. `docs/evidence/course-variety13/` records the
actual baked layouts and metrics.

Expansion scenery mixes at least three silhouettes per landscape and fills
groves, districts and infields beyond 220 m from the road. Near scenery uses
224 m spatial cells, with road clearance, actual terrain grounding, open-water
exclusion and existing clearings respected. Urban routes have 3D streetlights
and themed facades; horizon silhouettes persist beyond detail culling. Each
course has an authored Sky with its own palette and orientation, clouds,
sun/moon, stars, aurora/storm treatment or a planet and nebula.

Quick Race and Time Trial expose Random Track in the fixed footer. It chooses
uniformly among all other courses, then updates the focused card, preview,
description and race configuration. Painted trackside signs use 768×512 runtime
PNGs, retaining the original 1536×1024 sources and their separate hashes.


### Original 3D landmarks and motion for the thirty additions

`ExpansionSetPieces.SPECS` assigns a unique landmark composition to every
addition. Actual meshes, rather than additional painted copies, supply its
architecture. Deterministic planning avoids the named landmark beats and all
road branches, scores forward approach visibility, faces standalone landmarks
toward that approach, and reserves tree-canopy sightlines before scenery batches.
Spanning features retain a 12 m tested camera/driving corridor; standalone and
animated silhouettes stay inside conservative road-clear footprints. Foundations
meet the actual surrounding terrain. Features have no driving collision.

The shared motion material supports turning rotors/rings, upright orbiting wheel
cabins and flowing water streaks. All effects stop under Reduce Motion; they use
no per-frame scene callbacks. Spatial distance culling and bounded mesh budgets
remain required. Large display-font signs warm their actual font, size and
course-name glyphs during loading. Geometry, compatibility and source/asset
identities remain separate; this revision preserves content 13/protocol 7/save 1.


### Selection browsing with the expanded roster

The fixed footer exposes an All/New/Classic/Asphalt/Dirt/Space/Night filter with
its available count. New means additions after the established ten; Classic
means the established ten. Asphalt/Dirt refer to actual tire surface rather than
verge appearance. Space follows the authored space setting; Night includes dark
space environments. Random shuffles the current list into a nonrepeating tour,
counting the current selection as visited on first use. A new cycle includes
every member and avoids repeating the previous selection at its boundary.
Each distinct list retains its unfinished tour for the app session, across
filter and Quick/Trial changes. Manual selections count toward the current
list's existing tour. This private menu RNG does not consume gameplay RNG or
write profile/save data. Selecting a filter that excludes the current course
selects a valid member. The preview, description and actual race launch always
use that selected index. Addition descriptions explain the current route's
driving rhythm and a recognizable scene, using the roster's authoring text.

Phone cards prioritize readable names and distance/difficulty facts beside small
postcards. Focus scrolling exposes the name/facts target. Race configuration and
trial-ghost controls belong in the selected-track detail panel, not at the end of
the complete roster. Fixed footer controls, filtered focus and minimum touch rows
must fit supported phone/tablet/desktop scales, including 884×398 at 150 percent.


### Expansion neighborhood and lighting identity

Festival districts use a mix of round pavilions and striped open stalls. The oasis
uses domed sandstone blocks, arched windows, towers and crenellations, with simpler
distant silhouettes beyond 210 m. Both use spatial batches and foundations sunk
to the real terrain. Other districts and the established ten retain their paths.
Night streetlight pools follow the actual banked road and terrain verge, fade at
70–115 m and cull at 120 m even when draw distance changes. Their static additive
meshes add no dynamic lights, collision, shadow maps or per-frame callbacks.


### Expansion ground and sky identity

The thirty additions share one world-space ground material between their terrain,
verge and distant skirt, with a palette and seed per course. Ten static treatments
cover meadow, snow/ice, dunes, concrete, salt, craters, crystal, red strata, basalt
and wet soil. Fine detail fades with pixel footprint. These materials change no
road surface, grip, geometry or collision. The established ten keep their path.
The five space courses have distinct celestial settings: homeworld, ringed giant,
binary moons/nebula, dusty Mars with small moons, and reactor eclipse. Cloud-bank
shapes also differ among the five terrestrial regions. No flashing or automatic
camera effects are added by the sky/ground shaders.


### Course transport motion

Alpine Meadow's eight cable cabins follow a closed two-lane cable circuit while
their floors remain level. Neon Underpass's three-car metro shuttle reverses
within the viaduct. GPU-only translation uses complete swept culling bounds;
geometry stays above the actual road and 12 m camera corridor at every phase.
Reduce Motion freezes the authored starting arrangement. These props have no
collision, gameplay authority or per-frame scene callbacks.


### Small roadside life on the additions

Each addition uses three small object types appropriate to its region, drawn from
36 original faceted models. Their fronts face the road; footprints clear all
road branches, actual terrain/verges, water, posters, authored landmarks and hero
approaches. The planting exclusion includes wide sprite footprints, not only
sprite roots. Local small-object batches cull at 180 m even after settings
changes, with no collision, shadows or per-frame callbacks. The established ten
retain their existing props and placement paths.


### Distant terrain profiles and protected road surface

The thirty additions use fourteen deterministic distant landform families with
course-specific amplitude, frequency and phase. Relief begins beyond a 286 m
vertex guard and blends in by 436 m, preserving every triangle intersecting the
240 m road band. Coastal flattening follows relief so open-water levels remain
intact. Salt flats, wetlands and cities remain comparatively flat. The original
ten terrain exports/metadata and every course's chunk/triangle budget remain
unchanged. Frozen version-13 original vertex hashes and sea runs audit the actual
GLBs, including the original grid diagonal and absence of duplicate faces.


### Regional ambient motion and water accessibility

Temple Coast's bell and Sakura Ring's nine lanterns sway gently about their
hanging pivots. Copper Mesa's eight ore pieces travel through the conveyor's
covered ends. Complete swept custom bounds retain the geometry throughout each
cycle, above every road branch and the 12 m camera corridor. Motion uses the
shared GPU material with no scene-frame callbacks or driving collision.
Oasis Citadel's aqueduct has a slow horizontal surface flow. Reduce Motion
freezes all of these and the shared ocean/waterfall-pool normal waves, retaining
the original moving water by default.


### Regional distant skylines

The thirty additions use 21 persistent skyline families: snowy peaks, alpine
ridges, tundra, karst, low islands, canopy, hills, terraces, dunes, salt flats,
mesas, prairie, crater rims, crystal spires, basalt benches, domes, harbor,
works, city, market roofs and festival pavilions. Two faceted layers use authored
height/phase values and haze colors per course. Coastal relief lowers toward the
authored seaward side. Distant built silhouettes and static window bands match
urban settings; thirty-six farm/utility sites punctuate the three open plains.

Each skyline is one unshaded mesh, 2,304–4,464 triangles, without shadows,
collision, frame callbacks or local-distance culling. Complete triangles stay
outside the circle enclosing every road branch, with at least 619 m additional
clearance in the current roster. The established ten retain their original
horizon geometry or spectacle skyline exclusion. The existing 3,000 m camera
far plane remains the rendering boundary; ordinary driving views complement
diagnostic landscape comparisons.


### Compact mobile course browsing

Mobile course selection keeps footer actions on one row using scaled label
sizes while retaining their normal scaled touch heights. Track names fit whole
words within their card, including outline space, with a 16 logical-pixel font
minimum. In short layouts, the decorative heading and mode share a compact row;
the mode caption retains its scaled body font. Large layouts keep the full header.

Initial and random selections reveal the current card after the header/grid
layout settles. Generation tokens cancel stale requests, and a bounded visibility
check corrects a later container adjustment. This applies to interior selections
as well as the final card, without changing shuffled tours or race configuration.


### Anchored coastal watercraft

Aurora Harbor has an icebreaker, Monsoon Delta has two cargo barges, Coral
Causeway has three outrigger sailboats with different cloth colors, and Container
Corkscrew has a harbor tug. Seven authored sites use actual ocean levels and
reserve narrow planting windows along their road approaches. Complete swept
footprints clear all road branches, visible verges, submerged terrain, existing
landmarks and hero/poster approaches. The original ten receive no new boats.

Each original faceted model has 160–292 triangles. Slow GPU roll and vertical bob
use complete swept culling bounds, with no collision, shadows or scene-frame
callbacks. They cull at 700 m, including after draw-distance settings change.
Reduce Motion freezes a level waterline pose. Actual Far Chase visibility is
checked separately from close views that demonstrate geometry and motion.


### Course photographs, maps and explicit Random entry

Quick Race and Time Trial put Random first in the course grid and retain the
footer shortcut. It uses the active filter and existing session shuffle tour.
Room Settings and Create Room put Random first in their course selector, resolve
it immediately to one real course, and show that course's shipped in-game
photograph and canonical map. Confirmation sends that resolved index; cancelling
leaves authoritative room rules unchanged. Random never becomes a network track
ID or a hidden second roll when starting the race.

The shared map retains all baked route samples, adds a distance grid, travel
arrows and checkered start marker, and plots the actual lap elevation profile.
The waiting lobby shows the same photograph/map to every member. Compact phone
Room Settings keep the selector in the header; compact lobby headers show the
course name, with shorter footer captions and host Kick in the scrollable body.
At 150% phone text size, both views remain above the fixed footer. Photographs
are static native scene renders; they add no live world loading to the menu.


### Content 14: continuous curves and composed landscapes

The owner's follow-up authorizes refining selected established courses too.
Palm Bay, Citrus Pass and Redwood Run, plus 25 of the expansion courses, now use
individually drawn uniform cubic B-spline plans. The basis is continuous through
second derivatives at control joins, so longer bends do not become straight
segments with abrupt corners. Each revised course has its own elevation stations.
Seven established routes and Aurora Harbor, Lantern Market, Saltflat Velocity,
Steelworks Sprint and Container Corkscrew retain their previous route definitions.
The roster spans approximately 2.65–10.58 km; speed circuits, compact flowing
courses, linked switchbacks and long crater circuits retain different demands.

`assets/source/curved_courses14.json` is the editable plan/elevation source. Run
`tools/author_curved_courses.py` after any older base roster authoring tool, then
`tools/bake_tracks.py` and `tools/content_hash.py`. Never edit a bake manually.
Content version 14 preserves protocol 7 and save schema 1. The frozen content-13
archive retains its records, ghosts, Cup and race bytes; those incompatible runs
do not resume or compete against current records.

All thirty additions and four classics (Palm Bay, Citrus Pass, Redwood Run and
Marina Lights) have named area parcels in
`assets/source/course_compositions14.json`. Trees occupy irregular groves with
mixed species and sizes. Building settlements use bounded solid 3D modules with
individual foundations, including one Lunar freight base, a separate survey
outpost, urban blocks, market squares and industrial yards. Lunar boulder fields
are solid geometry. Streetlights belong to specified street sections. Small
roadside props occupy authored service scenes instead of an every-180-metre row.
Only four expansion roads retain a selected generic overhead gate; their unique
hero set pieces remain. Nearby terrain ridges and persistent regional horizons
provide depth behind these places. All forty courses retain sky environments.

Run `tools/author_course_compositions.py` to apply placement changes to the source
and runtime presentation catalogs. Terrain changes additionally require Blender
`assets/source/generate_terrain.py -- --tracks=<ids>`. The additional midground
relief uses a 128 m vertex guard around every road branch, protecting the road
and visible verge across 32 m terrain triangles. The version-14 foundation pins
the reviewed actual exports; the older version-13 foundation remains historical.
Seven unchanged classic terrain exports retain their exact bytes. Native captures
and independent pavement/terrain clearance checks complement that byte contract.

`tests/authored_course_evidence.gd` renders the explicitly selected `preview_u`
locations into current in-game photographs for the course and lobby selectors.
The layout map continues to use the complete canonical route and elevation data.
This revision does not claim physical Android acceptance or human playtest feel
from headless fixtures or macOS still images.


The mixed courses retain actual braking sections: Terrace Touge, Copper Mesa and
Crystal Chasm combine long sweepers with approximately 50 m, 52 m and 41 m minimum
radii respectively. Dune Serpent uses a longer chain of broad esses. Street and
dock circuits still include straight blocks and square corners; continuous
curvature is an authoring option, not a requirement for every turn in the roster.

The menu display apron now sits wholly beside Palm Bay's pavement, with a raised
surface above its local ground. Its previous coplanar overlap produced visible
sand triangles and z-fighting on the road. The fix is confined to MenuStage; a
separate fixture intersects the actual apron footprint with every pavement
triangle and verifies four cars and eight preview angles without changing the
racing mesh.

The content-14 cosmetic city pass gives Neon Underpass five additional named
quarters with separate cinema, apartment, arcade and parking meshes. Full
transformed building footprints must not intersect neighbouring compounds.
Persistent city silhouettes use broad tangential fronts, keeping the existing
single-mesh 5,000-triangle ceiling and 550 m enclosing-road-circle separation.
Native multi-view and isolated before/after timing evidence is retained in
`docs/evidence/city-districts14`; it does not establish mobile performance.

Terrace Touge's cultivated hills and Copper Mesa's layered outcrops are authored
solid scenery meshes. Their closed bases descend 64 m and allow at most 60 m of
local ground relief; building foundations retain the 16 m limit. Actual base
triangle samples must remain below exported terrain, horizontal shelves must
face upward, and the full bounds must clear every road branch. The ordinary
700 m scenery culling, no shadows and no driving collision apply. Native views
and focused checks are retained in `docs/evidence/mountain-places14`.

Nine wooded courses now use deeper, named forest parcels with mixed species and
explicit tall-tree or understory size ranges where appropriate. Open beaches,
meadows and shrine approaches remain part of each composition. Existing road
reservations, spatial batches and culling apply to every enlarged tree. The
forest pass retains all frozen terrain and gameplay bytes; its 209-command gate,
native multi-view photographs and isolated before/after render timings are in
`docs/evidence/forest-places14`.

The five expansion space courses do not inherit Caldera's periodic speed gates
and crystal rows. Caldera retains those legacy details. Lunar freight and survey
sites have a single landing apron and bounded rover models; Orbital Gardens has
three planted courts with separate conservatory layouts and surrounding oxygen
groves. Martian buttes, crater outcrops and reactor basalt formations use solid
buried-base meshes with the same full-road and terrain clearance contract as
the other natural formations. Illustrated landmarks now complement these places
rather than being required to supply every landmark on their own.

Space-road paint and rails have separate materials and individual course colors.
Four airless expansion skies have static filtered stars and a subtle galactic
band, with planets and rings masking the stars; Mars keeps its dusty atmosphere.
The refreshed selection photographs and multi-view source evidence live in
`docs/evidence/space-places14`. These are cosmetic changes; route/collision and
frozen terrain geometry remain unchanged.

Glacier Ridge and Frostbite Fjord have distinct blue ice faces and squat glacial
erratics in individually positioned sections, alternating with broader sheltered
forests and open high ground. Their frozen terrain exports remain exact. The
Fjord waterfall now emerges from a solid natural headwall, without the sluice's
rectangular pylons; independent rays verify that its upper ice sheets meet the
actual cliff. Natural-mesh bases, complete road footprints and hero reservations
retain their existing checks. See `docs/evidence/ice-places14` for native views
and the focused validation results.

Cloudforest's waterfall uses its own asymmetric rocky formation, twin cascades,
fern crowns and a supported lookout instead of the sluice frame. Its upper stream
vertices must meet actual cliff triangles and its entire silhouette must remain
inside the existing standalone clearing. Native before/after pixels in
`docs/evidence/canopy-falls14` confirm visible water motion and zero changed
samples under Reduce Motion; the course and lobby photograph shows this place.


Marina Lights retains its classic route and five original landmark anchors, with
thirteen separately composed cinema, apartment, shop, gallery and harbor groups
and fourteen mixed gardens. Full building footprints remain disjoint, and garden
canopies reserve those footprints. Selected streets have light poles and light
pools; small shelter, cart and utility models have explicit classic renderer
support. The distant city is one persistent 1,584-triangle mesh with windows and
varied roof heights. World-space garden and paving materials span the existing
terrain and verge, adding no coplanar surface or driving collision. Opaque window
masks limit building emission to the panes. Existing terrain exports, route,
landmark tunnel collision and gameplay compatibility remain unchanged. Native
views and isolated eight-car comparison evidence live in
`docs/evidence/marina-places14`.
