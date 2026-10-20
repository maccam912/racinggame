# Clean local Build116 Android/macOS exports

Both release-mode exports identify clean source `855284555a14a5989ecf154a0c1307fa5dfe8941`, gameplay `f762fa68`, cosmetics `f6fadc28`. Native macOS Keychain/adapter and headless exported-game startup pass. Actual in-place phone/tablet APK updates preserve signer/UID and all **47/41 existing files** before launching the game.

Actual ordinary seven-opponent exported-APK captures: Palm Bay tick 1800 at **2400×1080**, Marina ticks 1200/1450/1800 at **2560×1600**. Raw captures are visually reviewed; they prove rendering/build identity rather than human driving or minimum-device performance. Palm's new roadside hut is visible in the normal driving view. Other closeup/render evidence separately shows cargo/crates.

The [actual exported macOS Citrus recording](../footage/) includes loading, Grid/countdown and 30 ordinary racing seconds. Fixed60Hz MovieMaker output is encoded as H264/AAC without artistic edits, **36.383333 s / 1280×720 / 60 fps**; this is presentation evidence, not measured host FPS. The final unretouched engine frame/build sidecar, original command, raw/encoded hashes and ffprobe remain. Only the exact invocation-owned profile is archived. Raw AVI remains in the ignored `build/roadside116-footage/` folder. Decoded audio is nonzero (mean −24.0 dB, maximum −7.0 dB); no additional listening/quality verdict is implied.

Public CI artifacts and release publication remain separate and pending.
