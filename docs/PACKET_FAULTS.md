# Packet validation and receive limits

`WirePeer` consumes at most 256 raw ENet packets per poll, including packets it
discards. Remaining packets stay queued for the next poll. Legal game payloads
remain limited to 1,200 bytes; only server-to-client transition events may use
the existing bounded fragment assembler. Both transport and authority discard
packets from retired peers, including later entries in a batch that already
caused a disconnect. Deferred-pass and discard counters are numeric only.

This bounds the application's receive batch. It does not bound ENet's internal
service work or socket buffers and is not volumetric denial-of-service
protection. The [Godot ENet wrapper](https://docs.godotengine.org/en/4.6/classes/class_enetmultiplayerpeer.html)
owns transport reliability and buffering. Tests stage a real reliable queue in
small network batches to isolate application draining from OS receive-buffer
overflow; all 512 messages are queued before either application poll.

Control JSON is validated before converting bytes to a string. Overlong UTF-8,
invalid continuations, surrogate encodings, values above U+10FFFF, raw NUL and
escaped NUL fail quietly. The last case prevents Godot replacing an escaped NUL
with U+FFFD and accepting a changed name. Literal escaped backslashes remain
valid. The engine runner treats any Unicode replacement diagnostic as failure.
No Variant/object deserialization is used on the racing socket.

Client control events use channel 0, clock replies channel 3 and snapshots
channel 2; wrong-channel events and malformed messages cannot refresh liveness.
Worker liveness is refreshed only by a decoded input with a tick inside the
existing window or a validated ping. Arbitrary JSON, malformed inputs and empty
events do not keep human control alive. Unknown/invalid payloads cannot finish
a car or change its position/laps. Repeated Loaded for the same completed
preparation does not increment the lobby revision again.

The existing 120-packet/s and 64 KiB/s client budgets still apply, with sustained
offenders removed after five seconds. Missing valid input/heartbeat still causes
takeover after three seconds, and normal reconnect uses the same reserved
identity. These are validation/queue changes, with unchanged content, protocol,
input windows, collision, simulation and save formats.

`tests/packet_fault_tests.gd` exercises:

- UTF-8 boundaries, 1,024 seeded scalar samples, 93 invalid encodings, raw/escaped
  NUL, multilingual/emoji text and literal backslashes.
- A real 512-packet ENet queue: 171 oversized packets discarded and 341 legal
  packets delivered once over two bounded application passes.
- A real eight-car worker with healthy client prediction/controls, malformed
  input length/race/buttons/text, client fragments and a fabricated finish.
- A sustained offender that still sends valid heartbeat traffic, followed by
  reconnecting that owned reservation and sending only malformed traffic below
  the rate cap. The healthy driver's identity and authority continue throughout.
- Invalid/wrong-channel client receive data and stale packets after forced drop.

The full source gate runs the fixture and CI uploads its numeric JSON alongside
the check report. The separate two-lap faulted race/reconnect test validates
ordinary moving correction populations and complete authoritative results.
Local application tests do not establish physical mobile radio behavior, public
hosting capacity or universal network resilience.
