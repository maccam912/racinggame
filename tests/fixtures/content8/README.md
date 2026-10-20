# Immutable content-8 compatibility fixture

Captured from isolated source commit `958478afcb986e6b38597108958644be08ea44cd`, before content-9 implementation. The copied cars/tracks/rules/compatibility files are exact source bytes. `freeze_source.gd.txt` creates a valid Archive Eight profile, fresh Cup, explicitly synthetic 0.1-second Palm record/ghost and an actual 600-tick, eight-car in-progress Quarry race. No earned result or performance is claimed. No online identity is created.

`profile/manifest.json` pins every component and the exact old gameplay hash `dfb78c447e094d7e0200a2538fec45cae44c848a4e3c65334f642fb970b415f7`. Current-version tests assert its SHA-256 and verify that opening incompatible records, ghost, Cup and active race preserves every file byte while disabling current comparisons and continuation. Never regenerate these historical files under later gameplay code.

The isolated editor import crashed while importing fonts; the first capture attempt failed on missing imported font resources and was terminated. Copying the already-imported matching source resources repaired the isolated editor cache; the subsequent capture in `freeze.log` passes. The frozen gameplay files and script were not changed for that repair.
