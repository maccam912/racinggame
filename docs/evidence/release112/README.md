# Public Build 112

[Release](https://github.com/maccam912/racinggame/releases/tag/v0.0.112-dev), [required workflow](https://github.com/maccam912/racinggame/actions/runs/39403531221). All 32 required jobs pass; the two AI/soak jobs correctly reuse unchanged gameplay acceptance. All 18 files, tag, six metadata files and six stored payload digests are verified in `publication-verification.json`. Source `8b9fe9a62fd45d29d66a63d8efbf31cb5d1cff2c`, gameplay `f762fa68`, cosmetics `15a71230`.

`published-android/` separately records the exact downloaded public APK updating the actual public 111 APK on a new owned emulator, with all 28 file bytes and UID/signer preserved, followed by ordinary Spillway tick-1800 graphics with seven rivals. The untouched image is visually reviewed. This is emulator execution, not physical-device, human-driving or minimum-hardware performance evidence.

The clean local Android/macOS exports and fixed-60-Hz gameplay recording retain their separate [waterworks identity and evidence](../waterworks112/). Public macOS/Linux/Windows payloads keep their CI native gates; no additional local graphical execution is asserted for those public Build112 binaries.
