# Family driving assists (content 20)

Optional local corner braking uses the baked braking line. It eases throttle,
then adds at most 65% brake; stronger manual braking is preserved. Steering and
input identifiers are unchanged. Straight-line speed, manual handbrake, recovery,
boost, reversing, wrong-way and airborne control bypass the helper. Quick Race
and Cup support it; Trial, School and online prediction do not use local settings.

The delayed digital-input probe holds left/neutral/right steering for 0.6 seconds
with full accelerator and Strong steering help. Corner braking reduces wall
contact ticks from 1038 to 785 on Palm Bay, 946 to 790 on Storm Chase, and 2912 to
2091 on Temple Coast. All six runs finish without recovery. Assisted laps take
longer. This is a regression proxy, not human or physical-device acceptance.
Reproduce with `tests/corner_assist_driving_tests.gd`.

Races with eligible assisted humans allow 7200 ticks after first finish; ordinary
races retain 1800. Finished assisted humans still count, bots/DNF humans do not,
and the overall 36000-tick bound remains. Unit/session checks cover both deadlines,
manual overrides, input preservation, unchanged straights and the hard cap.
Local UI settings, retry/resume, host authority/prediction, race recovery, archive,
network codec and frozen content-19 transition tests pass. A final focused run
passes seven commands after the final tuning. The broader content-19 baseline
passed 218 commands with three corrected reruns; a new full run follows this
checkpoint. Source fixtures and generated reports distinguish these scopes.

Optional upcoming-turn arrows are enabled by Relaxed setup or Gameplay settings.
They preview the road without changing input, hide under warnings/countdowns and
results, and use metric or imperial distance. Native desktop and 1600x720 touch
views were inspected. Direction, lap-seam, priority and control safe-area tests
pass; five focused source/HUD/settings commands pass.
