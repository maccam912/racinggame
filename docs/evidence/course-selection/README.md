# Course selection evidence

Random is first in the offline course grid and online course selector. Manual and random selections resolve to a real course immediately, with a matching in-game photograph and detailed canonical map. Confirmation keeps the shown choice; cancellation preserves the current lobby rules.

The final required source gate passed all 204 commands. Widget checks cover every course, full nonrepeating random tours, desktop/phone layouts at 100% and 150%, confirmation, cancellation, and hosted-room controls. The existing 90 event layouts and 28 filter cases also pass. `widget-tests.json` and the other metrics come from the source gate. The twelve PNGs and `native.log` are a separate native Compatibility run on Apple M5 Pro using phone layout overrides.

`network.json` and the retained fixture/log verify two manual and two random choices through a real localhost ENet authority and second client, including the host lobby photograph/map update after the authoritative revision. No Android runtime or physical-device claim is made.

`checks-before-host-layout.json` preserves the first full pass. The final `checks.json` includes the subsequent fix that places previews above room-code sharing controls.
