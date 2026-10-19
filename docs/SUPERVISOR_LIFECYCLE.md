# Managed worker recovery and rollout

The supervisor now keeps its worker context alive after the first SIGINT/SIGTERM.
It atomically stops new process starts, withdraws public readiness/admission,
closes its public listener and persists drain for workers associated with its private
endpoint, including recovered survivors and legacy rows. Its private
listener remains alive while those workers finish. The existing worker retirement
contract permits up to ten minutes of active play and five seconds of final-row
delivery. A second signal forces termination of that supervisor's owned pool.
Graceful exit waits for both the allocator's completion callbacks and that scoped
SQLite worker set to become empty. A recovered worker is not an owned child, but
its private supervision remains alive through completion. Other pools keep their
own listeners and are not included in this wait.

Worker stdout/stderr use direct null-device handles. An `io.Discard` writer had
created supervisor-owned pipes; the crash fixture observed the worker stop soon
after parent death. Direct null handles let the actual worker retain its race
and UDP transport through the tested supervisor SIGKILL/restart. Production logs
still receive fixed structured process/performance events, excluding raw engine
output and user/credential text.

After exclusively binding its private and public listeners, a replacement drains
surviving rows associated with that private URL (plus legacy unassigned rows).
Survivors authenticate using their existing per-worker credential and receive
Drain on their next heartbeat. A fifteen-second private-link outage also retires
the worker once, and a later success cannot reopen it. No worker is reconstructed
from invented race state, and no profile or result is manufactured after a crash.

Reconciliation runs every five seconds. Fresh startup reservations remain held.
Stale or draining rows keep their UDP reservation while an exclusive IPv4/IPv6
bind probe finds the port busy. Only the allocator's own child may be signaled;
unknown survivors release their metadata when the port becomes free. An overdue
unknown busy port emits the fixed `worker_unowned_port_busy` operator code at
most once per minute and remains reserved for operator investigation.

SQLite **schema 3** adds private-owner URL, fixed drain deadline and the latest
authenticated numeric performance report. Versions 1/2 migrate transactionally;
immutable SQL fixtures preserve their historical layouts. Encrypted guest bytes
and bearer sessions survive the tested upgrade. Admission reads committed fresh
measurements from SQLite, so overlapping supervisors see the same headroom.
The configured `--host-workers` cap applies across all pools sharing that local
database and defaults to `--workers`. A legacy/missing performance report still
blocks additional capacity under the production measurement policy.

```sh
build/pacific-directory drain --db var/directory.sqlite --worker WORKER_UUID
build/pacific-directory drain --db var/directory.sqlite --all
```

These filesystem-authorized commands drain the selected current workers. For a
whole supervisor, the first process signal also stops future allocation. There
is no public administrative HTTP endpoint. Repeated drain requests preserve the
earliest deadline. Heartbeats cannot reopen a draining room or pending ticket.

For overlapping pools, use the same local SQLite database and cryptographic keys,
separate private listeners, disjoint UDP ranges and separate log folders. Stop
the old public supervisor with its first signal, then start the replacement on
the released public listener with its new worker executable/private listener and
UDP range. For example, keep old private `8081` / UDP `27020–27027` alive while
new private `8083` / UDP `27028–27035` serves the released public `8080`; set the
same measured host cap on both. Use immutable exported worker paths. The old pool
finishes while the new pool accepts compatible rooms within shared capacity.
Both supervisors must support schema 3; the first upgrade from an older service
needs a stopped-service database backup/migration before this overlapping mode.
An older binary refuses the newer database rather than downgrading its contents.

```sh
go -C services/directory test -race ./...
python3 tools/godot.py --headless --max-fps 60 --script tests/worker_directory_tests.gd
python3 tools/directory_lifecycle_integration.py
```

The process matrix uses isolated keys/data and actual ticket-required workers and
clients. It checks idle operator drain, graceful active-race completion,
SIGKILL/restart recovery, two simultaneous pools, shared-capacity rejection and
existing bearer continuity and graceful shutdown after recovering a survivor.
A fixture-only release gate forces a synthetic
finish after the real retirement signal; it validates lifecycle/transport, not
genuine lap times or gameplay records. Every owned worker row is reclaimed and
ephemeral keys are removed. Hosted regions, real deployment/backup drills,
physical phones and arbitrary host/storage failures remain separate acceptance.


The recovered-stop regression first observed the replacement exit while its old
worker was still racing: [before](evidence/m5-recovered-drain-before.json).
The repaired five-scenario native matrix passes, with zero remaining worker rows
and no cleanup issues in every case: [matrix](evidence/m5-recovered-drain-matrix.json).
Repeated shutdown preserves the earliest retirement deadline. Unknown PIDs remain
unsignaled; query/reconciliation failure reports an operator error after cleanup.
