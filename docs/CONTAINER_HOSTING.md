# Linux OCI region hosting

The runtime image contains the verified Linux server bundle, its matching
operator, runtime package inventory and licenses. Its Ubuntu 22.04 base and the
separate Caddy image are pinned by digest in `tools/toolchain.lock`. Only Linux
x86-64 is supported by this image. No operator keys or database enter image layers.
The CI image is built from the server ZIP after verifying its release checksum,
service checksum, build identity and safe archive paths.

A stable Tini init reaps adopted children. A small wrapper restarts a crashed
directory child while its exported race workers remain alive. The replacement
uses the same local data, keys and private endpoint, recovers their authenticated
heartbeats and drains them under the existing ten-minute deadline. It never
manufactures saved race state after losing a worker. First SIGTERM requests a
normal drain; repeated signals reach the directory's explicit force path. The
wrapper waits through an interrupted shell `wait` so it cannot return early
while Go is still draining recovered workers. Container/host loss remains a
separate failure from restarting the directory child inside a live image.

`pacific-directory probe --listen 127.0.0.1:8080` checks the local readiness route
with a three-second deadline, bounded JSON and no redirects. It uses the existing
trusted-loopback proxy contract and refuses remote/implicit hostnames. A draining
service is unready while its private listener and running races remain alive.
Docker health status does not itself restart this image. The example's
**11-minute stop grace** covers the existing ten-minute race drain and final rows.

## Set up a region

Use an owned Linux host with the image's runtime requirements, an owned HTTPS
address/worker DNS or IP and measured host capacity. The included Compose example
uses host networking, so its private supervisor/worker traffic remains on
loopback and no Docker socket is mounted into the image. Allow public TCP 443 and
only the configured UDP pool in the host firewall; keep public-backend/private
HTTP ports on loopback. The service runs as UID/GID 10001 with dropped capabilities,
read-only root filesystem and a private temporary filesystem. Persistent data
and logs use dedicated named volumes. Caddy has its own persistent certificate
and configuration volumes.

From the server bundle's `operator/deploy/container` directory, copy
`region.env.example` to an operator configuration outside versioned releases.
Fill every placeholder using the exact release `build.json`, a digest-pinned
server image, region identity, unique host ports and measured worker caps.
`PR_DATA_VOLUME` and `PR_LOG_VOLUME` name the same local region volumes across
compatible rollout pools. Distinct regions must select distinct data/keys.
Do not place key contents in the environment file.

```sh
docker compose --env-file /operator/region.env --project-name pacific-west \
  --file compose.yaml config --quiet
docker compose --env-file /operator/region.env --project-name pacific-west \
  --file compose.yaml run --rm --no-deps region keygen \
  --keys=/var/lib/pacific-rush/keys
docker compose --env-file /operator/region.env --project-name pacific-west \
  --file compose.yaml up --detach
```

Key generation is once per new region and refuses replacement. Original keys are
required for old encrypted identities; protect a recoverable copy separately.
New named volumes inherit the image's service-directory ownership. Existing
operator-managed volumes must already permit UID 10001 to access their private
files. The example validates configuration and creates no public region until an
operator supplies actual infrastructure and runs it.

The published image reference appears in the development release notes after the
image and platform packages build successfully. Network and service tests run in
the separate manual **Extra tests and soak** workflow. GitHub Container Registry
package visibility is separate from repository/release visibility; access may require an
operator login. CI uses the repository's scoped `GITHUB_TOKEN`, with package write
permission only in the final publisher. No registry token is embedded in the image.
No anonymous-pull or production-publication claim follows from preparing a context.

## Backups, updates and retirement

Run the existing `backup` command against the region's mounted database into a
new dated backup folder, then copy the verified complete folder to protected
backup storage outside the host. Keep original keys separately. Perform the
monthly isolated restore/auth/ban/empty-lease drill described in the backup
runbook. Container volumes alone are not an off-host backup or a restore test.
Use one-off operator containers with the same local volume for backup; no live
main-file copy substitutes for the CLI's consistent WAL snapshot.

For a compatible rollout, keep the existing HTTPS proxy on its stable backend
port. Stop only the old `region` service first so it closes public admission but
keeps its private listener and old UDP pool alive. Start a new pool from its
versioned Compose project with that released public port, a different private
listener, disjoint UDP ports and a separate `PR_POOL_ID` log directory. Reuse the
same local data/log volume names, original keys and shared measured host cap.
Start **only `region`** in the new project while the existing `https` service owns
443; do not launch a second proxy on that port. The old pool retires after its
races finish, while the proxy routes the stable public backend to the new pool.
Follow the supervisor runbook for initial schema upgrades and incompatible builds.
Do not force-remove an active production region or its volumes during a rollout.

## Validation and publication

Local source tests exercise the wrapper's owned child crash/restart and delayed
signal completion. The manual **Extra tests and soak** workflow verifies runtime
identity/native adapter, then uses eight signed real clients and all four cars in one ordinary
two-lap race. It kills only the image's verified directory PID, observes a fresh
heartbeat from the **same worker process**, requests image stop while that
recovered race is active, receives eight identical genuine finishes, and checks
clean exit and temporary volume removal. It has no synthetic finish or profiles.
The fixture applies a two-CPU cgroup quota and 1 GiB total image memory; it is
not the specified dedicated host benchmark, physical touch test or impaired soak.

The shared package workflow saves the built image into a checksum-verified CI
artifact. Manual container tests load that image and its matching build context.
The regular build's final publisher loads its image, pushes its numbered GHCR
tag, records its immutable digest and publishes the ordinary **18**
desktop/Android/server release files.
The image is an additional registry distribution, not an extra desktop download.
The full ten-race impairment/memory and native exported-worker checks also run
in the manual workflow; development publication does not wait for them. No public
regions, production schedules, publisher certificates or store submissions are
created by these example files.

References: [Docker signal and health configuration](https://docs.docker.com/reference/dockerfile/),
[init and process management](https://docs.docker.com/engine/containers/multi-service_container/),
[GitHub Container Registry permissions and digest references](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry).
