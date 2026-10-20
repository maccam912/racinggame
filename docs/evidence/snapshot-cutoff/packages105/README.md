# Corrected content 7 local Build 105 packages

Clean-source APK and macOS packages identify commit `0aa032b`, content/protocol/save 7/5/1, gameplay `0e06e18b` and assets `bd9bd532`. APK/macOS binary checksums and build metadata are retained; binaries remain in local build/download and are not duplicated in Git.

Both rooted Android emulators update in place with signer/UID and all 45 phone / 39 tablet preexisting files preserved. The macOS export passes native-adapter and headless driving startup.

The first installed-APK mixed race failed in the harness before race startup: `am start` returned before `pidof` could observe the app. Original failure and cleanup report are retained. The harness now waits up to 15 seconds for a single numeric PID; subsequent observations still require the same live process. No app restart or gameplay timeout relaxation was added.

The corrected run `mixed-android-105-73535680` passes two actual installed-APK plus seven-native-client races on Skyline Splice and Quarry Switchback: 16 matching finishes, all eight identities, two real GPU load sequences and two committed result journals. Eight independent UDP proxies apply 50 ms one-way latency, ±20 ms jitter and 1% independent datagram loss. Duration 301.53 seconds; no cleanup issues. The profile is isolated and archived by the tool. The APK is clean even though the native harness/visual working tree was dirty, explicitly recorded in the summary.

One old-race packet is rejected at a race boundary; valid late-course updates continue. This is not a zero-invalid-packet claim. Android correction magnitudes, physical touch, human handling, cellular, thermal and minimum hardware performance remain unmeasured. The one-lap native comparison is result agreement; the tool's separate three-lap clear-correction gate was not invoked here. These local packages are separate from GitHub publication.
