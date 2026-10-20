# Iroh multiplayer — 20 October 2026

Online now exposes Host by Code / Join by Code using the same live rendezvous
service as Mega Chamomile. The foreground host runs the existing RoomServer in
an isolated physics viewport; clients use the normal prediction/lobby/results
path over native Iroh. Gameplay/content/save identity remains content 10 /
protocol 6 / schema 1, game `70dbe372`, cosmetics `ed9ac660`.

- [Final source gate](source-checks.json): all **106 commands pass**.
  The [initial gate](initial-source-checks.json) retains its one failure: the
  ENet-specific packet-fault fixture needed an explicit concrete peer cast
  after WirePeer became transport-independent. The corrected real packet-fault
  scenario and complete second gate pass. Full logs remain in the recorded
  `reports/checks-6e00725ee2/` folder.
- [Frozen-source eight-client run](native-eight.json): **two races / 16 matching
  normal finishes**, all four car types, eight identities, five-second reconnect
  and rematch. Minimum clear-road samples **516**, worst p95 correction
  **0.0275175 m**. Its 34 exact source hashes and copied fixture inputs remain in
  `reports/iroh-1e77d71a72/`; the end-of-run source stability check passes.
  The 50±20 ms / 1% impairment affects application packets, independently of the
  underlying QUIC transport; it is not an external UDP-proxy measurement.
- [Raw channels](raw-channels.log) and [relay-only repeat](raw-relay.log): all
  four channels work in both directions, with 1,200-byte reliable frames and
  727-byte snapshots, in-flight cancellation and forced disconnect. The relay
  repeat uses `--iroh-relay-only`, which disables both endpoints' IP transports.
- [Actual app lifecycle](source-ui.log): real host self-admission, isolated
  authority world, expiry disabling Copy, code replacement without changing
  identity, double-activation protection, mobile host shutdown and revocation.
  The [150% native lobby](source-host.png) was visually reviewed.
- [Installed Android APK plus seven native clients](android-eight.json):
  **two races / 16 matching finishes**, exact complete result-digest agreement,
  same Android PID, two GPU preparations and two committed result journals.
  [The actual result screen](android-results.png) is retained. This population
  uses the [earlier local119 APK identity](android-crossplay-build.json);
  its Iroh library SHA matches the final package's adapter.
- [Final APK hosting](android-host.json): the final local119 APK admits its own
  local racer and a real native guest. Actual Home backgrounding closes the
  transport and revokes the code while backgrounded. The [host](android-host.png)
  and [return screen](android-host-background.png) were visually reviewed.
  Wi-Fi was restored to its original disabled state after each owned fixture.
- [Final in-place APK update](android-update.json): signer/UID and all **35
  existing files** remain unchanged before launch. Earlier successful update
  checkpoints separately preserved the original 28 files. Both local119
  APK generations are labeled separately; these are development exports.
- [Final exported macOS startup](native-macos-smoke.json) passes platform/native
  and ordinary driving probes. The actual exported app also [hosts and admits
  its local racer](exported-macos-host.log), with a [reviewed native frame](exported-macos-host.png).
  That graphical host capture precedes the final notice/expiry presentation
  adjustment; the final source lifecycle test covers that adjustment.
- Source-built [universal macOS](manifest-macos.json) and [Android ARM64](manifest-android.json)
  libraries pass their source/payload checks. Linux and Windows builds are
  configured in the shared package workflow; no remote run is claimed here.

Earlier Android attempts are retained as [offline](failed-android-offline.json)
and [network preflight](failed-android-network-preflight.json) failures. An
[optional Python HTTP checker](failed-python-http-probe.json) was denied by the
service's browser-signature policy; the successful reverse-host check uses the
unmodified shipped Godot discovery client and makes no service-policy changes.

All evidence is local and uses dirty implementation exports based on `64d2996`.
No new public release, remote CI success, physical Android or production relay
operation is claimed. The concurrent CI split is preserved: build libraries and
exports remain in `packages.yml`; Iroh acceptance is in manual `extra-tests.yml`.
