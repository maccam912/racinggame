# Pacific Rush Iroh extension

Derived from [tipragot/godot-iroh](https://github.com/tipragot/godot-iroh), exact
commit `153979fc02f86b10802358ae38fb74204fbf179a` (MIT; LICENSE retained).
This is a source-built project adapter, not Mega Chamomile's older v0.1.5 binary.
Cargo.lock pins Iroh 1.2.0, gdext 0.5.5 and all transitive crates; Godot API floor
is 4.5 for the project's 4.6.3 engine.

Project modifications:

- Independent `pacific-rush/iroh/1` ALPN and `pacific_iroh` library name.
- Bounded send/receive queues, 16 transport peers, four channels and existing
  application packet budgets; disconnect closes queued peer state.
- In-flight client cancellation and server connection-refusal handling.
- No Godot logging from Tokio worker threads; lazy two-thread runtime.
- Explicit relay-only native construction for network acceptance.
- Android JNI application-context initialization, ARM64 cross-build support,
  universal macOS and per-platform source/payload manifests.

The GDScript adapter uses raw MultiplayerPeer packets, without installing a
high-level MultiplayerAPI or nesting ENet in QUIC. Runtime build and gameplay
acceptance instructions are in [docs/IROH.md](../../docs/IROH.md). Original and
dependency notices are bundled under `assets/licenses/`.
