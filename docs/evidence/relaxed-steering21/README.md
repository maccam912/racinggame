# Gentler Relaxed setup

Relaxed setup now selects the existing 75% steering sensitivity option, in
addition to Strong centering, corner braking, auto acceleration and turn arrows.
Standard controls retain their defaults. The setup button is visible above the
course photograph and route map.

A Comet with steering held for 0.9 seconds between digital decisions now finishes
all six smooth courses against three Easy rivals. Palm and Festival previously
failed to finish with 100% sensitivity; they now finish within 0.4 and 1.0 seconds
of the next rival. Storm improves from 104.1 to 88.0 seconds. Every run visits
all four running positions; outcomes include first and fourth. Easy AI pacing is
unchanged. These synthetic inputs are a regression proxy, not child playtesting.

The same three-road comparison at 0.6-second decision intervals also finishes.
Five focused checks pass for source, actual preset/input preference propagation,
cold restart, 90 event layouts and 36 filter cases. Native phone preset view
reviewed. `tests/relaxed_field_tests.gd` reproduces the six-course slow-input case.

The extended `tests/relaxed_field_tests.gd -- --all-cars` check passes all 48
combinations of eight cars and six smooth courses. It uses the same 0.9-second
digital decision interval, 75% steering, auto acceleration and three Easy rivals.
Boost is not pressed. [Full results](all-cars.json). This is a scripted control
regression, not evidence that every child can finish every course.
