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
