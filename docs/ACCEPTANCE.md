# Current acceptance evidence index

This index maps the 32 required rows in DESIGN.md §30 to executable coverage and
retained evidence. It is a review aid, not a declaration of launch readiness.
The owner's emulator-only decision replaces the historical physical-device
requirement; human handling/usability and operated public regions remain open.

Current gameplay is **content 9 / protocol 5 / save schema 1**, digest
`f762fa68aa71c7e869d62e309713aedb9c40dc0eb938b28ec9ea6db5ff53e32f`, with ten playable courses.
The current [102-command source report](evidence/caption117/source102/summary.json)
passes after the following-gap contract and pause/settings caption correction.
The earlier waterworks and car/near-plane matrices retain their original identities. [Car/camera evidence](evidence/car-crater111/) retains
all 40 corrected native framing cases and both original failed reports; the
[later waterworks detail](evidence/waterworks112/) has its own native/source proof.
[Content-9 evidence](evidence/content9/) also
retains 600 field races, 40 Gold trials, 60 camera paths and the 80-case actual
native scale/layout matrix. Each source-test link below points to its executable
fixture; screenshots alone do not establish a numeric pass.

Current [Build116](evidence/release116/) passes all 33 required jobs, all 102 source commands and the full Linux ten-race soak, publishes 18 verified files and has actual public APK/macOS startup/gameplay evidence. Historical platform evidence keeps its original build and compatibility label.
[Build 108](evidence/release108/) passes all 40 remote jobs and publishes all 18
files. Build 110 passes all 43 jobs and publishes the ten-course game.
[Build 111](evidence/release111/) passes 32 required jobs with two correct
unchanged-gameplay skips, publishes all 18 files and has actual public APK/macOS
execution evidence. [Build 112](evidence/release112/) separately passes all 32
required jobs, publishes all 18 waterworks files and has actual public 111-to-112
APK update and gameplay evidence. Build 113's new-course network fixture fails
clear-sample coverage and is retained as [failed evidence](evidence/ci113-clear-coverage/initial-failure/).
The [Linux render audit](evidence/render-gate98/)
remains historical failed evidence, with corrected actual Linux GPU/readiness
execution in [Build 108's diagnostic](evidence/graphics108/linux-diagnostic/).

“Automated” means the listed scope has executable evidence. “Partial” identifies
a remaining procedure or platform boundary. Neither substitutes for human feel.

| ID | Current coverage | Evidence and remaining boundary |
| --- | --- | --- |
| DRIVE-01 | Automated | [Driving fixtures](../tests/driving_tests.gd): Comet 0–100 km/h 1.650 s, capped speed, straight-line repeatability. |
| DRIVE-02 | Automated | [Driving fixtures](../tests/driving_tests.gd): 20.806 m stop and delayed reverse. |
| DRIVE-03 | Automated | [Driving fixtures](../tests/driving_tests.gd), [hill presentation](../tests/hill_presentation_tests.gd), [60 complete camera paths through ten actual fast-car laps](evidence/content9/camera60.json): repeatable steering, slope following and static/terrain clearance. Human cornering feel remains an owner review. |
| DRIVE-04 | Automated | [Driving fixtures](../tests/driving_tests.gd), [feedback](../tests/race_feedback_tests.gd): grip restoration, slip and bounded visual feedback. |
| DRIVE-05 | Automated | [Engine world fixture](../tests/world_tests.gd): sustained wall scrape, tangential retention and penetration bounds. |
| DRIVE-06 | Automated | [Car contact](../tests/race_contact_tests.gd): bounded pair impulses and barrier interaction. |
| DRIVE-07 | Automated | [Slope/speed jump fixtures](../tests/jump_track_tests.gd), [60 actual Summit cases](../tests/summit_landing_tests.gd), [content-5 evidence](evidence/content5/). |
| RACE-01 | Automated | [Swept progress/gates](../tests/progress_touch_tests.gd): skipped/reverse gates and no false laps. |
| RACE-02 | Automated | [Sub-tick ordering/ties](../tests/race_contact_tests.gd), [eight-player APK rematch](evidence/content5/android91-crossplay.json): authoritative order and exact result agreement. |
| RACE-03 | Automated | [Mode/session rules](../tests/mode_tests.gd): finish grace, hard cap and DNF behavior. |
| RACE-04 | Automated | [Recovery fixtures](../tests/progress_touch_tests.gd), [world safety](../tests/world_tests.gd), [hold assistance](../tests/recovery_assist_tests.gd). |
| AI-01 | Automated | Current [macOS ten-course matrix](evidence/content9/ai600/summary.json): 600 races / 4,800 finishers, zero recoveries, plus 12 single-car ordering cases. [Build 110](evidence/release110/) independently passes all ten course matrices on Linux; Build 111 correctly reuses that unchanged-gameplay baseline. |
| TRIAL-01 | Automated | [Medal/ghost rules](../tests/ghost_medal_tests.gd), [atomic matched pairs](../tests/ghost_transaction_tests.gd), [content transition](../tests/content_transition_tests.gd), [40 valid standing-start Gold laps](evidence/content9/gold40.json) with every car/course through ordinary shared-controller inputs and zero recoveries. Human skill/difficulty confirmation remains open. |
| CUP-01 | Automated | [Cup/save/tie rules](../tests/save_cup_tests.gd), [frozen old-content preservation](../tests/content_transition_tests.gd). |
| NET-01 | Automated Mac/Linux matrix | Current clean [following-gap full ten-race run](evidence/ci115-ten-race-coverage/spacing-full-ten/) passes 80 matching normal finishes, minimum 2,793 clear samples, worst p95 .0406286 m and declining comparable RSS peaks.  [Build 108 Linux ten-race soak](evidence/release108/ten-race-soak/): 80 matching finishes, worst clear p95 .041917 m, minimum 945 clear samples, 2.514% RSS growth. Current [content-9 two-course/eight-client check](evidence/content9/eight-client-new-courses/summary.json): 16 matching finishes, minimum 2,179 clear samples and final checkpoint 74/88 on every client. [Content-9 Build 110](evidence/release110/ten-race-soak/) also passes 80 matching finishes, minimum 1,671 clear samples, worst p95 .0345315 m and .210478% RSS growth; operated regions and the specified server-host hardware benchmark remain separate. |
| NET-02 | Automated local matrix | [420-second real UDP contact run](evidence/content5/macos-contact420.json): 104 episodes, 1,576/1,204 samples, p95 .5993/.6859 m. Synthetic contact/reset transitions are explicitly excluded from ordinary-driving claims. |
| NET-03 | Automated local matrix | [Actual 250 ms added RTT / 8% real-loss run](evidence/network-degraded-content5.json), [quality thresholds/UI](../tests/network_quality_tests.gd) and [remote bounds](../tests/network_contract_tests.gd). Both clients finish three laps, show poor-tier observations and exercise the 150 ms extrapolation cap. One initial transport timeout resumes the same slot before GO. Human degraded-tier handling remains unmeasured. |
| NET-04 | Automated | Required CI real UDP reconnect/expiry scenarios and [real lobby lifecycle](../tests/lobby_reconnect_tests.gd), [mobile online lifecycle](../tests/online_lifecycle_tests.gd). Five-/25-second cases preserve identity or DNF without invented results. |
| NET-05 | Automated | [Packet faults](../tests/packet_fault_tests.gd), [Go service tests](../services/directory), [ticket-required engine fixture](../tests/worker_directory_tests.gd). Real TLS/SQLite, malformed traffic and final-seat contention are separate checks in CI. |
| NET-06 | Automated local/CI | [Lobby rules](../tests/lobby_tests.gd), [supervisor lifecycle](SUPERVISOR_LIFECYCLE.md), [tested container checkpoint](evidence/container-ci84.json). Public US/Europe hosting is unconfigured. |
| UI-01 | Partial | [Menu paths](../tests/menu_flow_tests.gd), [input ownership](../tests/input_ownership_tests.gd), [focus/repeat](../tests/menu_repeat_tests.gd), [choice scrolling](../tests/choice_picker_tests.gd). Automated native events are separate from human keyboard/gamepad/touch traversal. |
| UI-02 | Partial | [Layout/scroll bounds](../tests/menu_scroll_tests.gd), [80 native/headless event layout cases](../tests/event_layout_tests.gd), [18 results combinations](../tests/results_visibility_tests.gd) and current [ten-course native UI references](evidence/content9/ui/). Clean Build 110 phone/tablet/desktop captures are tracked in the newer status checkpoint. Broader human readability remains open. |
| SAVE-01 | Automated | [Atomic/durable save faults](../tests/durable_save_tests.gd), [native persistence runbook/evidence](SAVE_DURABILITY.md), [future/incompatible archives](../tests/content_transition_tests.gd). |
| MOBILE-01 | Partial | [Independent pointers](../tests/progress_touch_tests.gd), [ownership](../tests/input_ownership_tests.gd) and real APK driving/cross-play. Ten races of actual two-thumb touch input have not been established by autodrive. |
| MOBILE-02 | Partial | Current [local116 real Android OS-contact smoke](evidence/roadside116/os-multitouch/) verifies independent steering/brake contacts and Home/release/return/resume with neutral controls.  [Five-pointer/cancellation](../tests/progress_touch_tests.gd), [layout edits](../tests/touch_editor_tests.gd), [device ownership](../tests/input_ownership_tests.gd). Real emulator captures prove the touch HUD, not physical gestures. |
| MOBILE-03 | Partial | [Focus/checkpoint/resume](../tests/mobile_services_tests.gd), [Android service bridge and retained emulator drills](ANDROID_SERVICES.md), [cold checkpoint UI](../tests/checkpoint_ui_tests.gd). Current content-9 source coverage and actual APK startup are tracked separately; old OS-interruption evidence keeps its original build. |
| MOBILE-04 | Partial | [Default-route replacement](../tests/online_lifecycle_tests.gd), [actual emulator bridge/handover checkpoint](ANDROID_SERVICES.md). No physical carrier transition is claimed; hardware is optional owner follow-up. |
| MOBILE-05 | Automated emulator | Current [Build 112 six-race APK/native run](evidence/waterworks112/mixed-six-race/) passes 48 identical finishes, six GPU loads/result commits and explicit process-memory limits (434,458,624-byte peak, 2.246021% growth). The earlier [Build 110 APK/native pair](evidence/content9/packages110/mixed-eight-client/) passes both new courses with 16 identical finishes, two GPU loads and result commits. Earlier [Build 95 ten-race APK run](evidence/android-ten95/): 80 matching finishes, eight retained identities, 50±20 ms / 1% datagram loss and ten graphics loads. Native p95 and actual Android process RSS are separate populations; OS-overlay screenshots do not prove readability. |
| PERF-01 | Partial | [Server network/memory soak](evidence/content5/macos-ten-race-soak.json), required exported Linux worker and constrained OCI race gates. The [live graphical measurements](GRAPHICAL_SOAK.md) retain actual draw intervals and RSS. Content-8 catalog cycling failed the unchanged growth guard; a separate heavy-course repeat passed. The clean [content-9 Caldera/Spillway repeat](evidence/content9/render-lifetime-new-courses/) passes seven races with 1.855422% RSS growth and 18.336/19.048 ms racing p95/p99. The [current car/waterworks native repeat](evidence/waterworks112/native-lifetime/) independently passes seven races at asset `15a71230`, peak RSS 818,970,624 bytes, declining comparable peaks and 18.314/18.945 ms racing p95/p99. These are separate from minimum-hardware acceptance. Physical thermal checks are waived. |
| AUDIO-01 | Automated output; human listening open | [Decoded eight-engine/music/impact capture](../tools/audio_acceptance.py), [DSP/caption rules](../tests/race_audio_tests.gd), [retained audio measurements](evidence/m4-audio-acceptance.json). Required CI repeats real decoded output. |
| ACCESS-01 | Automated layout/motion | [Accessibility settings](../tests/accessibility_settings_tests.gd), [HUD](../tests/race_hud_tests.gd), [results visibility](../tests/results_visibility_tests.gd). Human comprehension remains open. |
| RELEASE-01 | Partial | Required native package startup/save gates, [versioned packaging](RELEASE.md), [actual offline Android install/reinstall, byte-preserving updates and published artifact execution](INSTALLATION.md). Local identity-loss help is rendered and reviewed. Publisher signing/notarization, human comprehension and store acceptance remain open. |

The current export, CI and publication results are tracked at the top of
[STATUS.md](STATUS.md). That distinguishes source checks, clean local exports,
downloaded CI artifacts, tested images, published release files and hosted service
operation. A green workflow is not a claim that the owner's business inputs or
human acceptance have been supplied.
