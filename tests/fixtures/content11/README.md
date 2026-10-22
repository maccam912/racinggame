# Frozen content-11 archive

Captured before changing gameplay content for the forty-course expansion.
The gameplay hash matches source commit `373c970` exactly. The one-time
producer is `tests/freeze_content11.gd`; its guard refuses to overwrite this
manifest or run under a different content version.

This contains a synthetic 0.1-second record/ghost, a fresh Coast Cup, a valid
profile and an actual 600-tick eight-car race. It does not represent an earned
player record. `content11_transition_tests.gd` checks every frozen component
hash and verifies that opening it under content 12 preserves the exact bytes,
while disabling record comparison and incompatible continuation.
