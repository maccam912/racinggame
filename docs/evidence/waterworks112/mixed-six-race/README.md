# Six repeated new-course races: actual Build112 APK + seven native clients

Run from clean native source `b92a53f86f280ed266ea7debfa2db5c358652f47` using the exact installed local clean Build112 APK from `8b9fe9a62fd45d29d66a63d8efbf31cb5d1cff2c`. Game/runtime/assets are identical between those commits: gameplay `f762fa68`, cosmetics `15a71230`. Fixture hashes and exact source are retained. Later changes during the run affect only workflow/documentation/evidence.

Command: `python3 tools/mixed_android_acceptance.py --serial emulator-5580 --number 112 --races 6 --laps 1 --seconds 1400 --tracks spillway_sprint,caldera_crosscut --impaired --check-memory`. Eight independent real UDP proxies apply 50±20 ms per direction and 1% independent datagram loss, including ACKs.

**Pass:** 48 complete matching authority/Android/native finishes, same eight identities and Android PID, six actual graphics-prepared transitions and six committed result journals; 1,193.122 seconds, no cleanup issues. Every native client sees final gates 74/88. Separate arithmetic over all 42 native race metrics confirms minimum 854 clear samples and worst clear p95 **0.0408212 m**, retaining the 500/.25 m limits. These are native correction measurements, not Android correction metrics.

Explicit process-memory checks pass with full minute-5/15 coverage: warm-up peak **424,914,944 bytes**, repeated-cycle/whole-run peak **434,458,624 bytes**, growth **2.246021%**. The unchanged limits are 1 GB process VmRSS and inclusive 5% growth. Every raw observation/loading peak remains in the report. This emulator process population excludes separate GPU/emulator-host allocation and establishes neither physical/minimum-hardware nor human touch performance.

Screenshots are raw emulator captures at the fixture transition; they do not establish readability or human driving. The failed early interruption remains separately preserved in `../../emulator-memory-scope/initial-interruption/`.
