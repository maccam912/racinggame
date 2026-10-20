# Six-course camera clearance matrix

`tests/course_camera_acceptance.gd` drives a standing-start Needle lap on each
actual course using ordinary shared Medium-driver inputs. Each lap alternates
Near, Far and Hood plus two look-back phases, giving 36 exercised paths and
22,080 clearance samples. The real exported terrain height grid and static
collision world are used. All six laps finish validly with zero recovery, terrain
coverage is finite at every sample, and no static overlap or cosmetic-floor clip
is measured. The .23 m test sphere leaves 2 cm tolerance inside the production
.25 m camera collider. Terrain-only clearance has a 3.468 m minimum; road/static
collision is tested separately within the same run.

This headless geometry fixture does not establish human framing preference,
graphical performance, every off-road pose or a synchronized image comparison.
It joins the required source matrix. `run.log` and the complete original report
are retained; the full 92-command source run is separately in `../source98/`.
