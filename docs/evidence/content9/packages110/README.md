# Clean local Build 110 packages

Android APK and macOS ZIP identify clean `95660b7013375212548f9bbae4aba708c72bd5c7`, content/protocol/save **9/5/1**, gameplay `f762fa68` and cosmetics `1fe44b97`. Exact package metadata and SHA-256 sidecars are retained here, separately from GitHub publication.

Both rooted Android 15 emulators pass in-place updates, preserving signer, UID and every preexisting file: **46 phone / 40 tablet files**. The actual installed APK renders ordinary seven-opponent races at tick 1,800 on Spillway Sprint (phone, 2400×1080) and Caldera Crosscut (tablet, 2560×1600), with touch HUD and unretouched engine readbacks. Metadata verifies packaged source, ordinary AI inputs, current settings and PNG digest.

The actual exported macOS binary passes its Keychain adapter and headless startup/driving smoke, recording exact package/executable digests. Separately, graphical execution of that extracted binary renders both ordinary eight-car courses at tick 1,800 and 1920×1080, with matching source/asset metadata. All four PNGs were visually reviewed. Invocation-owned diagnostic profiles remain isolated; no physical hardware, human handling, other OS graphics or minimum-device performance claim.

The [actual APK plus seven native-client run](mixed-eight-client/) passes both new courses: 16 matching finishes, two GPU loads/results journals, minimum 1,635 native clear samples and worst native clear p95 0.0338212 m. The new-course scene-lifetime run is recorded separately when complete. Remote Build 110 release is pending at this checkpoint.
