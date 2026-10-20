# Actual Android ten-race impaired-network run

Clean local release APK Build 95, commit `9d50b49`, content 5 / protocol 5,
Android 15 ARM64 `pacific_rush_install_95` emulator (`emulator-5584`). The helper
runs from source checkpoint `8d7a432` with its recorded dirty worktree and exact
helper SHA. This predates the later staggered launch fixture. The APK bytes,
metadata and complete measurements retain their original identities.

Command:

```sh
python3 tools/mixed_android_acceptance.py --serial emulator-5584 --number 95 --races 10 --laps 3 --seconds 2400 --impaired
```

Ten three-lap races alternate Palm Bay and Citrus Pass. The actual graphical APK
and seven independent native clients use eight real UDP proxies, each adding
50±20 ms in each direction and dropping 1% of datagrams, including ACKs. All
**80 finishes**, full authority/client rows and Android parsed-row hashes agree;
all eight identities remain, with exactly ten Android result commits and graphics
loads. All native client/race clear populations exceed the unchanged 500 minimum;
worst native clear p95 is **0.041211 m**. Android corrections are not measured.

Elapsed time is **2,196.144 seconds**. One unchanged Android process is sampled
throughout; VmRSS peaks at **417,374,208 bytes**. The repeated loading/racing-cycle
peak through minute five is 398,508,032 bytes; the 5–15-minute peak is 417,374,208
bytes, **4.734202%** growth. The 1 GB peak and 5% cycle-growth gates pass. GPU and
emulator-host memory, physical thermals and minimum hardware are outside this
measurement. All raw observations and native/proxy/authority logs are retained.

The selected disposable emulator alone had Wi-Fi enabled. The helper archives
only its owned diagnostic profile and reports no cleanup issues. The screenshots
include Android's fresh-install “Viewing full screen” / “Got it” overlay. They
are retained as actually captured and do **not** establish unobscured UI
readability or touch ergonomics. Separate 150% phone/tablet result captures in
the installation checkpoint provide that narrower visual evidence.
