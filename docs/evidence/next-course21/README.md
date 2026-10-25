# Keep racing through the selected roads

Quick Race results add Next Course (Next on phones). It uses the selected road
filter's existing shuffled tour and carries the race's car, paint, lap count,
rivals, difficulty and contact setting. The next event gets fresh grid entropy;
Retry retains the current event's seed. Driving preferences remain unchanged.

The new selection is saved in Quick Race preferences. Canceled loading returns
to the same results. An unresolved save failure blocks advancement until the
existing explicit save/dismiss path is handled. Trial, Cup and online keep their
own result actions.

Focused coverage passes the six-course no-repeat Smooth tour, setup preservation,
cold preference reload, save guard, canceled loading and an actual next race with
local steering/braking help. The initial test had a GDScript type annotation
error; the corrected standalone test passes. Four other focused commands pass
results geometry (18 scale/rank cases plus nine DNF cases), source compilation,
result receipt/save behavior and exact Retry seed/world behavior.

Native [phone](phone-150.png) and [desktop](desktop-150.png) results were reviewed
at 150% text. This is source-client evidence; physical device acceptance is separate.
