# Linux server bundle

Development server downloads include the stripped Linux x86-64 Godot worker,
`pacific-directory`, both build identities, native platform adapter, game and
service dependency licenses, Caddy configuration examples and operator runbooks.
The directory binary uses pinned Go 1.27.0 with CGO disabled; client packages do
not contain the regional database, operator service, keys or deploy files.

Extract into a new versioned directory on a Linux x86-64 host. Verify the adjacent
release SHA-256 before extraction. `build.json` identifies the game and includes
the directory binary's SHA-256 and source hash; `directory-build.json` matches
its embedded public identity. Preserve the complete extracted directory, including
the embedded-project executable and native adapter files. Keep persistent data outside versioned
releases. No operator keys or region database are shipped.

```sh
./pacific-directory version
./pacific-directory keygen --keys /var/lib/pacific-rush/keys
```

Create keys once. For a regional service, select the exact `protocol_version` and
`content_hash` from this bundle's `build.json`, an owned public HTTPS address,
the advertised worker DNS/IP and a measured worker cap. An example invocation
from an installation at `/opt/pacific-rush/releases/BUILD` is:

```sh
./pacific-directory serve \
  --db /var/lib/pacific-rush/directory.sqlite \
  --keys /var/lib/pacific-rush/keys --logs /var/log/pacific-rush/pool-a \
  --listen 127.0.0.1:8080 --private-listen 127.0.0.1:8081 \
  --public-url https://YOUR_REGION_DOMAIN --worker-host YOUR_WORKER_HOST \
  --worker /opt/pacific-rush/releases/BUILD/pacific-rush-server.x86_64 \
  --first-port 27020 --workers MEASURED_CAP --host-workers MEASURED_HOST_CAP \
  --protocol PROTOCOL_FROM_BUILD_JSON --content-hash HASH_FROM_BUILD_JSON
```

Replace all uppercase placeholders; the example does not deploy or select a
region. Run as an unprivileged service account with access to its private data
and log directories. The supervisor starts one ticket-required headless process
per room. Put the included `operator/deploy/Caddyfile` in front of public HTTP;
set its owned HTTPS address and upstream. Its separate private worker listener
stays on loopback and is never a public proxy route. Caddy certificate/account
state is persistent and separately protected.

Permit inbound HTTPS on TCP 443 and only the configured worker UDP range.
An N-worker pool beginning at 27020 requires UDP 27020 through 27020+N−1. Rolling
pools need disjoint permitted ranges, private listeners and log directories while
sharing one local database, original keys and measured host cap. Clients initiate
connections; ordinary players do not port-forward. Restrict HTTP/private ports
to the host. Size capacity from actual host measurements and leave headroom;
the default pool size does not establish production capacity.

The public `/healthz` and `/readyz` endpoints report service liveness/readiness.
Authenticated private heartbeats provide worker health. Readiness becomes 503
while draining. First SIGINT/SIGTERM stops new allocations and lets active races
finish for up to ten minutes plus final-row delivery; keep the private listener
alive. A second signal forces only the owned pool. Use the detailed lifecycle,
backup and performance contracts under `operator/` before operating a region.

For a separate community Direct Connect server:

```sh
./pacific-rush-server.x86_64 --headless -- \
  --server --auth-mode=direct_guest --port=27020
```

That explicit guest mode has no official directory identity/admission. The
operator exposes its chosen UDP port; do not share that port with a managed pool.

Native release CI executes the actual bundled binaries on Linux, compares their
embedded/sidecar/game identities and checksums, then runs the same isolated
backup/restart/auth drill with the **shipped** operator binary and two impaired
eight-client, two-lap races against the **exported** worker. The worker starts
from the extracted bundle without a source project path. These startup and
operator checks are separate from cross-play load, physical devices, public
hosting, scheduled backup drills and publisher release approval. OCI packaging
and public regional deployment remain separate work at this checkpoint.
