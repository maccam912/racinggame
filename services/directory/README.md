# Pacific Rush regional directory

Work in progress against DESIGN.md §20. No official region is deployed; local development is explicitly Test Region. Godot workers remain authoritative for room transitions and every race result.

## Implementation contracts

Public HTTP sits behind Caddy HTTPS. An explicit insecure-loopback mode is restricted to loopback. Worker heartbeats use a separate private listener never routed by public Caddy. Bodies are bounded and unknown JSON fields rejected. Only configured proxies can supply trusted client addresses. Errors are fixed codes, never traces.

Guests create a UUID and 256-bit secret locally. Registration transmits the secret over HTTPS; SQLite stores AES-256-GCM ciphertext with a deployment key outside the database. Authentication nonces are random, guest-bound, single-use and expire in 60 seconds. Proof is HMAC-SHA256 over `pacific-rush-auth-v1\n{uuid}\n{nonce}\n{NFC_display_name}`. A failed proof also consumes the bound nonce. Bearer sessions are random 256-bit values, last one hour and are stored only as SHA-256 digests. Names are not identity; name changes are limited to five/hour.

Admission tickets have a fixed RSA-2048/SHA-256 PKCS#1 v1.5 signature, matching Godot Crypto.verify. Format: `base64url(payload_json).base64url(signature)`, with no client-selected algorithm. Claims: format version, guest UUID, canonical name, room UUID, worker UUID, protocol, content hash, issue/expiry times and random single-use nonce. Lifetime is at most 60 seconds. A worker verifies signature, bindings, time, compatibility and nonce before spawning. `ticket_required` is operator configuration and cannot be downgraded by a packet. Reconnect remains a separate short-lived worker/race token. Direct-guest workers never receive the official guest secret.

Joining atomically reserves one human seat for 15 seconds. Count pending reservations and worker-reported active guest IDs as a union, capped at eight. Repeating a pending join replaces that guest's old reservation. Private-code failures are generic. Quick Join orders compatible public Lobby rooms by humans descending, age and room UUID, or creates a default room. Host room administration remains reliable worker events.

Allocation uses an operator-configured executable and bounded UDP/process pool; clients cannot supply paths/commands. Reserve allocation metadata in a short transaction, launch outside it and wait at most ten seconds for authenticated readiness. Per-worker heartbeat credentials are supplied through the environment. Workers report phase/rules/active guests every five seconds; advertisements disappear and joins fail after fifteen seconds without a heartbeat. Empty closure and graceful race retirement stay worker behavior.

SQLite uses WAL, foreign keys, busy timeout and serialized short writes. Allocation waits never hold a transaction. Prune expired nonces/sessions/reservations/rate state. Match all §20.2 limits with Retry-After. Logs exclude bodies, room codes, credentials and raw addresses. Production rotation, daily backup/restore drills and two hosted regions remain distinct gates.

## APIs and tests

Implement all public APIs listed in §20.1, health/readiness, and authenticated private heartbeat/admission consumption. Inject clock, database and worker allocator for expiry/replay, encrypted-at-rest checks, eight-seat concurrency, visibility, stale/readiness failures, compatibility, rate limits and generic code lookup tests. Verify Go-issued tickets in the pinned Godot engine, then directory-backed real-client race/rematch tests. Test Caddy/public/private boundaries separately. Client secure-storage adapters must precede official identity persistence; diagnostics never contain secrets.
