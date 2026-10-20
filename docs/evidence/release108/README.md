# Build 108 public release

[Development release](https://github.com/maccam912/racinggame/releases/tag/v0.0.108-dev) from clean `958478afcb986e6b38597108958644be08ea44cd`. All 40 jobs in [workflow 39379722661](https://github.com/maccam912/racinggame/actions/runs/39379722661) pass, including strict Linux render, eight AI matrices, all platform/native packages, network/directory/lobby/container checks and ten impaired eight-client races.

All 18 zero-padded desktop, APK, AAB and server files are public. The release tag and all six platform metadata files match clean source, gameplay `dfb78c44` and assets `f84503f5`; six payload sidecar checksums match GitHub's stored asset digests. Full JSON and publication verification are retained. This does not claim every published payload was downloaded/executed locally. Separate local clean-package and emulator checks are under `../city108/packages108/`.

The actual ten-race three-lap Palm/Citrus soak has 80 matching finishes, minimum 945 clear samples per driver/race, worst clear p95 0.0419169851 m and 2.514138% repeated-cycle post-warm-up peak RSS growth. All coverage, correction, wire, memory and lifecycle gates pass unchanged. Full client/server logs, reports, launch plans and exact fixture sources are under `ten-race-soak/`. This is the staged content-8 fixture.

Official regions remain unconfigured, and iroh/discovery remains a documentation-only future investigation. Automated emulator/native/CI checks do not establish human handling or physical thermal performance.
