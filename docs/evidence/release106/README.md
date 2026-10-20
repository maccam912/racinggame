# Build 106 published, all 40 workflow jobs pass

Release: https://github.com/maccam912/racinggame/releases/tag/v0.0.106-dev
Workflow: https://github.com/maccam912/racinggame/actions/runs/39373091746

The tag peels to exact tested commit `d326e37`. All six published build manifests identify that clean source, gameplay `0e06e18b` / content 7 / protocol 5 / save 1 and assets `1ece6157`. All 18 zero-padded desktop/Android/server files are published. The six binary checksum sidecars match GitHub's actual stored asset SHA-256 digests. Original full workflow, release REST metadata, tag and sidecars are preserved.

Strict native Linux graphics, all eight AI matrices, network/lobby/directory scenarios, native Windows/Linux/macOS arm64+Intel/server smoke and container publication pass. Ten actual impaired eight-client races finish all 80 cars with identical standings, minimum 1,104 clear samples, worst clear p95 0.0351754 m and 0.0216772% post-warm-up peak worker RSS growth. The fixture uses Palm/Citrus and the older index-ordered half-second holds. Build 105's original coverage failure remains unchanged in ../ci105-ten-race; this independently passing repeat does not remove the reason for the content-8 fixture improvement.

The release contains eight courses, original arcade menu/font/touch controls, richer car/pavement materials and grounded Skyline lamps/signs. The later traffic-level AI fix and city-window/nameplate polish are separate checkpoints. Remote native/graphics/soak evidence and published-file digest validation do not claim physical Android, other GPUs, human driving or a locally executed public APK.
