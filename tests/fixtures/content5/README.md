# Frozen content-5 transition inputs

Captured from `ce2b91c` before the bonus-track expansion. Cars, tracks, rules and
compatibility are byte copies. The profile contains a synthetic 0.1-second trial
record/ghost and fresh Cup, plus an actual 600-tick eight-car in-progress source
race on the content-5 controller. This is migration evidence, not an earned lap,
result or performance claim. No online identity was created.

`profile/manifest.json` binds all frozen components by SHA-256. Preserve these
bytes across later content revisions and reject incompatible continuation. Do
not regenerate fixtures to satisfy a newer implementation. The one-time capture
script and original log are archived as text; it refuses an existing manifest
and requires the original content-5 hash. Complete prior bakes/controller source
remain available in the cited Git commit and frozen compatibility manifest.
