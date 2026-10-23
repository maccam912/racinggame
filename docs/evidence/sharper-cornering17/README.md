# Sharper full-lock cornering

The shared controller doubles lateral grip and progressively adds up to twice
the steering target near full lock at road speed. Drift still enters through
ordinary steering. Yaw reduction now starts at 10 degrees of sideslip and
finishes at 30 degrees, keeping the rear closer to the direction of travel.

[Summary](summary.json) and [controller cases](steering-drift.json) retain
192 sustained-lock cases across eight cars, four surfaces, two directions and
three approach speeds. Another 64 measurements compare the first two seconds
of full-lock travel from top speed with the frozen content-16 controller:

- Travel curvature is 1.93–2.10 times the previous value.
- Cars retain 85.6–88.4% of entry speed on asphalt, and at least 80.4% across
  all four surfaces, after two seconds of uninterrupted full lock.
- Releasing steering, countersteering, handbrake behavior and snapshot replay
  pass the existing driving and drift checks.

All **214 local source commands pass**: [source report](source-checks.json).

All 320 standing-start car/course trials still reach Gold with zero recoveries.
All 240 camera paths across forty courses retain zero static overlaps and zero
terrain clips. These use the ordinary reference driver and real course collision.

[Before](before.json), [after](after.json) and the
[probe source](handling_probe.gd.txt) retain the additional 1/2/10-second
measurements. Radius is integrated travel distance divided by accumulated
velocity-heading change; it measures the traveled arc rather than body yaw.
The pre-change two-second radii are retained in
`tests/fixtures/content16/full-lock-reference.json` for regression checks.

Content is 17, protocol 8 and save schema 1. Frozen content-16 records, ghosts,
Cup and suspended-race bytes are preserved; incompatible comparisons and
continuation remain disabled.

These are deterministic controller and course checks. Human driving feel,
physical-device input and released packages are separate verification steps.
