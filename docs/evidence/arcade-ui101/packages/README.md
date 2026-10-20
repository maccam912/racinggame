# Clean-source local Build 101 packages

Android and macOS exports came from clean commit `8545b3c` with asset identity
`8fc08bbda8c0e2ba0209c57741ee7ddeb52e17e96feddb8f34d1642270e023ba`.
Build metadata, artifact checksums and full exporter logs are retained here.

The APK updated the existing phone/tablet emulator installations with matching
development signer and UID. The update checks compared every existing file
before/after installing, before game startup: all 32 phone files and 26 tablet
files survived byte-for-byte. No original profile was cleared or uninstalled.

Four actual APK main-menu GPU readbacks use new synthetic QA profiles, native
Android layout and 100/150% UI scale. No source mobile-layout override or image
retouching is involved. Logs contain the existing capture completion marker;
post-run profiles retain zero races/distance and are archived on their emulator.
The native macOS package separately passes platform-adapter/headless driving
startup. This is not a native macOS graphical-package capture or proof of other
OS releases. Public GitHub release publication is a separate gate.
