# Menu preview turnout

A native keyboard check of public Build 94 reproduced an illustrated palm close
enough to obscure the parked preview car during the automatic menu orbit. The
old cleanup selected only the former 3D grass batch names, so it missed the new
billboard faces and footprints.

The [native before report](before.json) finds six nearby instances, including a
palm **3.162 m** from the parked car. Four representative original before images
are retained. The [native after report](after.json) finds zero instances within
14 m and a nearest retained decoration **19.105 m** away. All 32 original native
[orbit views](after/) cover eight angles for each of four cars. Representative
views of all four cars, plus the actual production Main Menu and 150% Garage,
were visually inspected. No generated source bitmap was edited.

The preview now supplies its clearing before scenery instances are built.
Billboard faces and footprints receive the same filtered source placements;
3D LOD batches do too. An independent ordinary racing world retains all **1,966**
instances, while this preview retains **1,960**. There is no collision, handling,
save, gameplay identity or source asset-byte change. The former GPU instance
readback cleanup is removed.

The fixture requires a native renderer: Godot's dummy headless renderer returns
identity instance transforms and cannot establish this clearance. Its first
headless prototype is excluded. CI runs the real renderer through Xvfb and
retains the raw census, all 32 views and log.

```sh
python3 tools/godot.py --max-fps 60 --script tests/menu_stage_tests.gd -- --render
```

The [five affected source checks](source/summary.json) pass: shipped-script
compilation, menu paths, world presentation, memory-pressure recovery and menu
style. [Production menu references](menu-style.json) and their log are separate
from the isolated geometry/orbit fixture. These views do not establish human
handling preference, other GPUs or the final exported version of this fix.
