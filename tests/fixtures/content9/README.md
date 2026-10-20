# Immutable content-9 compatibility fixture

Captured from source commit `023d306582b52c9f18cd7009f8ea0ff02c03f80c` before the full-lock steering drift change. Cars, tracks, rules and compatibility files are exact source bytes. `freeze_source.gd.txt` creates a valid Archive Nine profile, fresh Cup, explicitly synthetic 0.1-second Palm record/ghost and an actual 600-tick, eight-car in-progress Quarry race. No earned result or performance is claimed. No online identity is created.

`profile/manifest.json` pins every component and the old gameplay hash `f762fa68aa71c7e869d62e309713aedb9c40dc0eb938b28ec9ea6db5ff53e32f`. Transition tests verify that opening incompatible records, ghost, Cup and active race preserves every file byte while disabling current comparisons and continuation. Never regenerate these historical files under later gameplay code.
