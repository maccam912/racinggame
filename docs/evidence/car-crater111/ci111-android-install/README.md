# Exact CI 111 APK — fresh emulator install and graphics

Downloaded `package-android` artifact **12254302206** from workflow **39398577112**, clean source `32c2472`, gameplay `f762fa68`, assets `d817e671`. APK SHA-256 **dbf1a78d1fec03a623d8f2fa794820c98efc449db1099d4702447e498a73f2c9** matches the artifact sidecar. These are the actual Linux-CI-built APK bytes, separately from local macOS exports.

A new initially-empty rooted Android 15 / Pixel 7 AVD, `pacific_rush_install_111_074223` on emulator-5586, passes all **10** guarded installation steps: offline native services/startup/preferences, cold protected test-key/save reads, owned uninstall, removed old app data, absent old key/save and reinstall/preferences. No player emulator is uninstalled. Actual OS setup completes to the launcher before testing.

The same actual CI APK also renders ordinary seven-opponent Caldera and Spillway races at tick 300 and 2400×1080, with touch HUD and unretouched engine PNGs. Publication is pending here; once released, compare the public APK digest to this exact tested artifact before claiming published-binary execution. No physical hardware, human handling or minimum-device performance claim.
