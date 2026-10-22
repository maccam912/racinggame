# Distinct space places

The five expansion space courses no longer inherit Caldera Crosscut's regularly spaced crystal rows and speed gates. Caldera keeps its original orbital decoration. Lunar Freight now has one solid freight lander/apron, a working base and survey rovers. Orbital Gardens has three individually arranged planted courts, conservatories and broad mixed-species oxygen groves. Mars uses eighteen surviving solid layered buttes instead of repeated arch sprites. Reactor Rift uses nine dark basalt formations, and Lunar Freight has six authored crater outcrops. Crystal Chasm retains its mineral landscape.

Road paint no longer mutates the cached guardrail material. Each new space course has a separate road/paint/rail palette; dirt keeps its existing driving surface. Airless skies now have filtered static stars, a subtle fixed galactic band, and planet/ring occlusion; the dusty Mars atmosphere is retained.

The five native scene photographs and shipped 512×288 course thumbnails were refreshed. Eight additional driving-height views per course and their source are included. The seven focused suites in checks.json passed, including all thirty expansion worlds, all thirty-three authored compositions, legacy Caldera, terrain materials and road partition geometry. Actual natural-base triangle samples remain buried under the exported terrain. Full mesh bounds clear every road branch, and the new solid modules remain below 1,500 triangles each. The frozen terrain contract and gameplay content hash are unchanged.

The source catalog now counts authored solid places alongside standalone illustrated landmarks instead of requiring an extra billboard where a substantial 3D place already supplies that identity. The actual-world fixture separately checks that all three botanical courts, the freight lander and survey rovers survive placement checks.

These captures and local checks establish the recorded macOS source behavior. They do not establish exported-package, physical Android, minimum-hardware or human driving acceptance.

An isolated live source run completed Orbital Gardens and Reactor Rift with all eight cars. At Medium, 1920×1080 and a 60 fps cap on the recorded Mac, 10,034 racing frames had p95 17.659 ms and p99 18.513 ms, with 1 frames above 33 ms. See performance.json; only the per-frame spatial array was omitted from the retained report. This is a current-run measurement, not a before/after comparison.
