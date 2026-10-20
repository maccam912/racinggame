# Iroh code multiplayer

Choose **Online → Host by Code**, then share the four-character code from the
lobby. Other racers choose **Online → Join by Code**. Everyone needs matching
Pacific Rush protocol/content. Ready, Start, room rules, car selection and
rematches work through the existing lobby. No regional directory deployment or
manual port forwarding is needed for this path.

The host runs the authoritative race inside its own game. Leaving or quitting
closes the room; Android backgrounding also closes a hosted room. Guests retain
the existing 20-second reconnect reservation. Codes last ten minutes; **New Code**
replaces/revokes an old code, and connected racers continue after expiry. Abrupt
process termination cannot revoke immediately, so the service expiry is the
fallback. There is no listen-host migration.

## Shared service and transport

The default and only shipped rendezvous endpoint is
`https://iroh-rendezvous.maccam912.workers.dev`, verified against the current
Mega Chamomile `autoload/net.gd` and the sibling `iroh-rendezvous` API. The game
uses POST/GET/DELETE `/v1/join-codes`, standard verified HTTPS, bounded responses,
ten-second timeouts and no redirects. `session_id` is
`pacific-rush/<protocol>/<full-content-hash>` so another game's code or another
Pacific Rush version cannot be used accidentally. Tokens remain in memory.

This service only resolves codes. Iroh uses N0 address lookup and its relay
preset separately, attempts direct connectivity, and carries application traffic
over authenticated encrypted QUIC. Public-relay operation is an external service
dependency; these development packages do not establish a managed relay SLA.

The transport preserves the four raw channels. Channel 0 uses reliable streams;
channels 1–3 use ordered datagrams. Current inputs are at most 82 bytes and
eight-car snapshots are 727 bytes, below the native 1,024-byte datagram budget.
Reliable messages retain the 1,200-byte application budget and existing bounded
fragmentation. Prediction, interpolation, collisions and authoritative results
use the existing shared race implementation. ENet is an independent path.

## Native build

Install Rust **1.98.1** with rustup, alongside the existing pinned Python/Godot
toolchain. `python3 tools/native_build.py host` builds both native adapters.
`python3 tools/iroh_build.py host` builds only Iroh. macOS builds both ARM64 and
x86_64 and combines them with lipo. Android ARM64 uses the pinned NDK and API 29
linker: `python3 tools/iroh_build.py android`.

The complete modified source and lockfile live in `native/iroh/`; provenance is
in its README. Generated libraries/manifests live in ignored `native/bin/` and
are checked against source and payload hashes before exports. The build pipeline
compiles Linux, Windows, universal macOS and Android libraries, merges their
artifacts and records the matching adapter in package metadata. Iroh integration,
raw channels, relay-only and app lifecycle checks are in the manual Extra tests
and soak workflow, following the concurrent CI workflow split. Dependency
notices ship with the game.

The Android PacificMobile plugin installs a process-lifetime application JNI
context before constructing Iroh endpoints, so Iroh reads the active network's
DNS configuration. It retains no Activity. The Tokio runtime starts lazily on
first Iroh use and owns two worker threads; offline and ENet sessions do not
start those threads. Android backgrounding closes an embedded authority rather
than continuing its simulation in the background.

Source launch shortcuts:

```sh
python3 tools/godot.py -- --host-code
python3 tools/godot.py -- --join-code=ABCD
```

## Validation

```sh
python3 tools/check.py
python3 tools/godot.py --headless --script tests/iroh_transport_tests.gd
python3 tools/godot.py --headless --script tests/iroh_transport_tests.gd -- --iroh-relay-only
python3 tools/iroh_integration.py --reconnect
python3 tools/godot.py --script tests/iroh_ui_evidence.gd -- --profile=iroh_ui_qa
```

The raw fixture verifies all four channels in both directions, packet budgets,
in-flight connection cancellation and forced disconnects. Relay-only mode disables
both endpoints' IP transports, exercising real relay connectivity. The live
integration registers/resolves/regenerates/revokes codes on the shared service,
then runs eight real Iroh clients through two races and a rematch, including a
five-second disconnection. Its 50±20 ms / 1% impairment applies to client
application packets; it is distinct from the existing external UDP-proxy ENet
tests and from real Internet latency.

For an already rooted, explicitly selected owned emulator, update the actual
release APK using `tools/android_update_acceptance.py`, then run
`python3 tools/iroh_android_acceptance.py <apk> --serial <emulator>`.
`--enable-wifi` temporarily enables Wi-Fi and restores its original disabled
state. This fixture uses a new named diagnostic profile, keeps unrelated data,
and compares the installed APK's full result digests with seven native clients
over two races. Android hardware, carrier changes, restrictive real-world NAT
combinations and production relay operations remain separate checks.

Dated results and exact retained reports are recorded in `docs/STATUS.md`.
