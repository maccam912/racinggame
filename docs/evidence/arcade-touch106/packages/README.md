# Clean local Build 106 follow-up

APK and macOS packages were exported from clean commit `7906385`, gameplay/content/protocol/save unchanged at `0e06e18b` / 7 / 5 / 1, assets `1ece6157`. Metadata and package checksums are retained. These are local packages, separate from the later GitHub Build 106 commit/artifacts.

The phone/tablet updates preserve the same signer and UID and all 45/39 preexisting files. Actual installed-APK ordinary races with seven opponents reach tick 1,800 on Skyline (2400×1080 phone) and Quarry (2560×1600 tablet); the new chrome TouchDriving overlay and original HUD render at native host resolution. These are unretouched live-race captures with diagnostic AI inputs, not posed car states. Synthetic QA profiles are archived independently of existing user data.

The macOS package passes the real Keychain platform adapter probe and exported-binary headless driving startup. The repeated provenance-aware check records the actual ZIP SHA-256, executable SHA-256 and build.json from that ZIP. This tool improvement also makes future GitHub native smoke reports traceable to their exact tested packages. It does not claim a new graphical or physical-device performance check.
