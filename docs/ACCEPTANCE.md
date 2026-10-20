# Current acceptance evidence index

This index maps the 32 required rows in DESIGN.md §30 to executable coverage and
retained evidence. It is a review aid, not a declaration of launch readiness.
The owner's emulator-only decision replaces the historical physical-device
requirement; human handling/usability and operated public regions remain open.

Current gameplay is **content 5 / protocol 5 / save schema 1**, digest
`4eaef43b6dd7efb40414a23b8f84f4f2902417f8e3a9d0d85bbeced354b3e69a`.
The [90-command source report](evidence/scenery-detail/checks.json) uses this
gameplay with the detailed scenery checkpoint. Each source-test link below is
the actual executable fixture; screenshots alone do not establish a numeric pass.
Historical platform evidence retains its original build and compatibility label.

“Automated” means the listed scope has executable evidence. “Partial” identifies
a remaining procedure or platform boundary. Neither substitutes for human feel.

| ID | Current coverage | Evidence and remaining boundary |
| --- | --- | --- |
| DRIVE-01 | Automated | [Driving fixtures](../tests/driving_tests.gd): Comet 0–100 km/h 1.650 s, capped speed, straight-line repeatability. |
| DRIVE-02 | Automated | [Driving fixtures](../tests/driving_tests.gd): 20.806 m stop and delayed reverse. |
| DRIVE-03 | Automated | [Driving fixtures](../tests/driving_tests.gd), [hill presentation](../tests/hill_presentation_tests.gd): repeatable steering and slope-following presentation. Human cornering feel remains an owner review. |
| DRIVE-04 | Automated | [Driving fixtures](../tests/driving_tests.gd), [feedback](../tests/race_feedback_tests.gd): grip restoration, slip and bounded visual feedback. |
| DRIVE-05 | Automated | [Engine world fixture](../tests/world_tests.gd): sustained wall scrape, tangential retention and penetration bounds. |
| DRIVE-06 | Automated | [Car contact](../tests/race_contact_tests.gd): bounded pair impulses and barrier interaction. |
| DRIVE-07 | Automated | [Slope/speed jump fixtures](../tests/jump_track_tests.gd), [60 actual Summit cases](../tests/summit_landing_tests.gd), [content-5 evidence](evidence/content5/). |
| RACE-01 | Automated | [Swept progress/gates](../tests/progress_touch_tests.gd): skipped/reverse gates and no false laps. |
| RACE-02 | Automated | [Sub-tick ordering/ties](../tests/race_contact_tests.gd), [eight-player APK rematch](evidence/content5/android91-crossplay.json): authoritative order and exact result agreement. |
| RACE-03 | Automated | [Mode/session rules](../tests/mode_tests.gd): finish grace, hard cap and DNF behavior. |
| RACE-04 | Automated | [Recovery fixtures](../tests/progress_touch_tests.gd), [world safety](../tests/world_tests.gd), [hold assistance](../tests/recovery_assist_tests.gd). |
| AI-01 | Automated | Final [macOS matrix](evidence/content5/ai-summary.json) and [Linux matrix](evidence/content5/ci91-linux-ai/): 360 races / 2,880 finishes each, zero DNF/recovery. Parent CI 91's separate contact-coverage failure is retained. |
| TRIAL-01 | Automated | [Medal/ghost rules](../tests/ghost_medal_tests.gd), [atomic matched pairs](../tests/ghost_transaction_tests.gd), [content transition](../tests/content_transition_tests.gd). Human confirmation of all gold targets remains open. |
| CUP-01 | Automated | [Cup/save/tie rules](../tests/save_cup_tests.gd), [frozen old-content preservation](../tests/content_transition_tests.gd). |
| NET-01 | Automated local matrix | [Ten-race impaired content-5 soak](evidence/content5/macos-ten-race-soak.json): 80 matching human finishes; worst clear p95 .03935 m. This is a development Mac, separate from operated regions and the specified server-host benchmark. |
| NET-02 | Automated local matrix | [420-second real UDP contact run](evidence/content5/macos-contact420.json): 104 episodes, 1,576/1,204 samples, p95 .5993/.6859 m. Synthetic contact/reset transitions are explicitly excluded from ordinary-driving claims. |
| NET-03 | Automated local matrix | [Actual 250 ms added RTT / 8% real-loss run](evidence/network-degraded-content5.json), [quality thresholds/UI](../tests/network_quality_tests.gd) and [remote bounds](../tests/network_contract_tests.gd). Both clients finish three laps, show poor-tier observations and exercise the 150 ms extrapolation cap. One initial transport timeout resumes the same slot before GO. Human degraded-tier handling remains unmeasured. |
| NET-04 | Automated | Required CI real UDP reconnect/expiry scenarios and [real lobby lifecycle](../tests/lobby_reconnect_tests.gd), [mobile online lifecycle](../tests/online_lifecycle_tests.gd). Five-/25-second cases preserve identity or DNF without invented results. |
| NET-05 | Automated | [Packet faults](../tests/packet_fault_tests.gd), [Go service tests](../services/directory), [ticket-required engine fixture](../tests/worker_directory_tests.gd). Real TLS/SQLite, malformed traffic and final-seat contention are separate checks in CI. |
| NET-06 | Automated local/CI | [Lobby rules](../tests/lobby_tests.gd), [supervisor lifecycle](SUPERVISOR_LIFECYCLE.md), [tested container checkpoint](evidence/container-ci84.json). Public US/Europe hosting is unconfigured. |
| UI-01 | Partial | [Menu paths](../tests/menu_flow_tests.gd), [input ownership](../tests/input_ownership_tests.gd), [focus/repeat](../tests/menu_repeat_tests.gd), [choice scrolling](../tests/choice_picker_tests.gd). Automated native events are separate from human keyboard/gamepad/touch traversal. |
| UI-02 | Partial | [Layout/scroll bounds](../tests/menu_scroll_tests.gd), [18 results combinations](../tests/results_visibility_tests.gd), actual exported phone/tablet/desktop captures in the newer status checkpoint. Broader human readability remains open. |
| SAVE-01 | Automated | [Atomic/durable save faults](../tests/durable_save_tests.gd), [native persistence runbook/evidence](SAVE_DURABILITY.md), [future/incompatible archives](../tests/content_transition_tests.gd). |
| MOBILE-01 | Partial | [Independent pointers](../tests/progress_touch_tests.gd), [ownership](../tests/input_ownership_tests.gd) and real APK driving/cross-play. Ten races of actual two-thumb touch input have not been established by autodrive. |
| MOBILE-02 | Partial | [Five-pointer/cancellation](../tests/progress_touch_tests.gd), [layout edits](../tests/touch_editor_tests.gd), [device ownership](../tests/input_ownership_tests.gd). Real emulator captures prove the touch HUD, not physical gestures. |
| MOBILE-03 | Partial | [Focus/checkpoint/resume](../tests/mobile_services_tests.gd), [Android service bridge and retained emulator drills](ANDROID_SERVICES.md), [cold checkpoint UI](../tests/checkpoint_ui_tests.gd). Content-5 source coverage and actual APK startup are current; old OS-interruption evidence keeps its original build. |
| MOBILE-04 | Partial | [Default-route replacement](../tests/online_lifecycle_tests.gd), [actual emulator bridge/handover checkpoint](ANDROID_SERVICES.md). No physical carrier transition is claimed; hardware is optional owner follow-up. |
| MOBILE-05 | Automated emulator | [Build 91 Android + seven native clients](evidence/content5/android91-crossplay.json): two complete races/rematches, 16 finishes, identical parsed authority rows and retained identities. |
| PERF-01 | Partial | [Server network/memory soak](evidence/content5/macos-ten-race-soak.json), required exported Linux worker and constrained OCI race gates. New six-course live graphical lifetime test is separate from a continuous worst-track run or minimum-hardware acceptance. Physical thermal checks are waived. |
| AUDIO-01 | Automated output; human listening open | [Decoded eight-engine/music/impact capture](../tools/audio_acceptance.py), [DSP/caption rules](../tests/race_audio_tests.gd), [retained audio measurements](evidence/m4-audio-acceptance.json). Required CI repeats real decoded output. |
| ACCESS-01 | Automated layout/motion | [Accessibility settings](../tests/accessibility_settings_tests.gd), [HUD](../tests/race_hud_tests.gd), [results visibility](../tests/results_visibility_tests.gd). Human comprehension remains open. |
| RELEASE-01 | Partial | Required native package startup/save gates, [versioned packaging](RELEASE.md), actual byte-preserving emulator updates in the newer status checkpoint. Publisher signing/notarization, clean-install/reinstall identity UX review and store acceptance remain owner inputs or separate tests. |

The current export, CI and publication results are tracked at the top of
[STATUS.md](STATUS.md). That distinguishes source checks, clean local exports,
downloaded CI artifacts, tested images, published release files and hosted service
operation. A green workflow is not a claim that the owner's business inputs or
human acceptance have been supplied.
