# Installation and local identity checks

Development APKs use a stable development certificate and release-mode exports.
They can update an earlier compatible development build without uninstalling it.
The current emulator-only scope is distinct from storefront or physical-device
acceptance. Publisher signing and macOS notarization are still open.

## Current public package checkpoint

[Build 117](evidence/release117/) is the latest verified published checkpoint: all
18 files and required CI/native package gates pass. Clean local117 phone/tablet
updates and macOS execution have [their own evidence](evidence/caption117/packages117/).
The exact downloaded public-binary execution below remains labeled Build116.

[Build 116](evidence/release116/) publishes 18 verified desktop/Android/server files.
Its actual downloaded APK updates public Build 112 on a separate Android 15
emulator while preserving all 28 files, UID and signer. The actual public macOS
binary passes platform/Keychain/headless startup; both public binaries also
render ordinary eight-car gameplay. The earlier fresh-install/reinstall and
same-version procedures below retain their original build identities.

## Fresh offline Android install and reinstall

The clean local Build **95** APK embeds clean commit `9d50b49`, content 5
(`4eaef43b…`) and cosmetic identity `442367da…`. A new Android 15 / API 35 ARM64
Pixel 7 AVD, `pacific_rush_install_95`, starts with no game installed. Wi-Fi and
cellular data are disabled only on this disposable AVD; the installed native
bridge confirms no default route.

The [unchanged raw report](evidence/install95/summary.json) passes actual install,
offline first-run rendering, cold-process protected-key and native-save writes
and reads, owned uninstall, absence of the old app directory, reinstall, absence
of the old key/alias and native save, and a fresh preferences screen. Both
[first install](evidence/install95/first_install_preferences.png) and
[reinstall](evidence/install95/reinstalled_preferences.png) renders were reviewed.
Observed readiness is around one second on this host, including polling; it is
not a first-frame or minimum-hardware benchmark.

The separate [eight-step cold-process storage sequence](evidence/install95/protected-store.json)
also passes absence, write, read/tamper rejection, replacement, replacement read,
erase, absence after erase and test-scope cleanup. This establishes Android
KeyStore behavior on the emulator; hardware-backed key storage is unmeasured.
No real official guest account is registered by either fixture.

The existing Settings → Data help explains that local storage identifies an
online guest, has no account recovery, and Android uninstall removes that guest
identity. The [150% phone-size render](evidence/installation-preparation/local-identity-phone-150.png)
and reset-failure/retry checks are separate from the OS install procedure.

Reproduce only on a **new, initially empty** installation-fixture AVD:

```sh
python3 tools/android_install_acceptance.py build/download/pacific-rush-00095-android.apk --serial emulator-5584 --expected-avd pacific_rush_install_95
```

The helper requires the exact AVD name, emulator/root properties and no existing
installation. Before uninstall it verifies its unique ownership stamp and the
installed APK hash. An existing phone/tablet test profile fails preflight without
uninstalling. Each invocation retains a separate report folder and all probes
use random test scopes. Never repurpose a player's emulator for this fixture.

## In-place update and published artifact execution

Clean local Build 94 updates preserve all **31 phone / 20 tablet files** before
launch, with the same UID and verified signer:
[phone](evidence/detail94/phone-update.json),
[tablet](evidence/detail94/tablet-update.json).

The exact public CI Build 94 macOS ZIP and Android APK were downloaded from
[v0.0.94-dev](https://github.com/maccam912/racinggame/releases/tag/v0.0.94-dev).
Every supplied package/metadata checksum line matches the original bytes;
[package provenance](evidence/published94/packages.json) retains the identities.
The actual public APK installs over the same-version local export while
preserving **all 32 existing files**, UID and signer:
[same-version reinstall report](evidence/published94/phone-same-version-update.json).
This is labeled separately from a forward-version update. The helper requires
`--allow-same-version` to accept equality; older versions never pass its gate.

Those downloaded artifacts complete all **12 actual exported captures**:
[six macOS](evidence/published94/desktop/summary.json) at 1920×1080 and
[six Android phone](evidence/published94/phone/summary.json) at 2400×1080.
Each captures racing tick 1,200 in an ordinary seven-opponent Quick Race with
normal HUD/touch controls, with no engine or resource-shutdown errors. Summit
desktop and Canyon phone views were visually inspected. This is separate from
the earlier locally exported 18-view phone/tablet/desktop checkpoint.

These procedures do not prove human onboarding comprehension, another OS's
graphical output, public hosting or store acceptance. Required CI separately
checks native package startup and persistence on the desktop platform matrix.
