# Private online corner braking

Content/protocol/save versions: 21/10/1. The host’s private Driving assists screen
adds **Strong + braking**. It combines the existing Strong steering nudge with
the same bounded corner helper available locally. Off, Gentle and Strong retain
their behavior. Each player receives only their own setting; other players’
assignments stay out of public rosters and lobby updates. Choices are locked
during races and survive reconnect/rematch. Local settings cannot override them.

Ten focused commands pass for schemas/hash, source, actual UDP authorization,
private data, reconnect/rematch, host UI, local boundaries, braking overrides,
codec and frozen content-20 save preservation. Twenty-four actual collision-world
cases cover all eight cars on Palm, Festival and Temple, with 180 authority/client
steps each and a delayed snapshot replaying 120 original input frames. Every
case applies braking and agrees within 0.00001 m in position/velocity; handbrake
and boost inputs are included. Native desktop/phone host UI captures reviewed.

The preceding content-20 full run passed all 223 commands, including 320 Gold
trials and 240 camera paths. A new full run follows this version checkpoint.
These checks do not establish physical Android feel or human multiplayer balance.

## Eight-client mixed-assist check

The native UDP soak now accepts `--assist-level 0..3`; the host assigns odd slots
and leaves even slots unassisted. It checks private lobby maps, own start settings
and prediction settings across rematches. Default runs remain unassisted.

A two-race Palm Bay / Temple Coast run with level 3 passes all 14 checks: sixteen
normal finishes, identical standings on all eight clients, and no engine errors.
Each proxy adds 50 ms one-way latency, +/-20 ms jitter and 1% independent loss.
Across 27,734 clear-road correction samples, the largest per-client/race p95 is
0.055 m; the smallest sample population is 827. Maximum measured IPv4+UDP rates
are 3,691 B/s upstream and 16,606 B/s downstream per client.

Run: `python3 tools/soak_acceptance.py --races 2 --laps 1 --minimum-seconds 0
--seconds 600 --tracks palm_bay,temple_coast --assist-level 3 --port 27640`.
Elapsed 271.6 seconds; this short run does not establish the 5-to-15-minute server
memory bound. [Recorded metrics](mixed-assist-network.json).
