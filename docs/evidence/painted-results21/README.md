# Recognizable paint colors in race results

Result portraits now use the actual frozen roster paint as well as the car model.
All eight paints for all eight cars are rendered from the existing shipped models
by `tools/render_car_portraits.gd -- --result-paints`. The 64 transparent 256x144
PNGs total 1,141,239 bytes; the asset gate enforces palette/model/hash identity,
complete coverage and a 1.5 MB ceiling. There are no extra live 3D viewports in menus.

[All combinations](all-paints.png) and [150% phone result](phone-150.png) were
visually reviewed. Source-script compilation, 18 result layout/scale/rank cases,
save-failure/retry receipts and actual Next Course loading pass in four focused
commands. The native phone render also passes actual touch dismissal of the
explanation while retaining Next-button focus. These are native macOS checks;
Build 167 Android continuation evidence predates these cosmetic images.
