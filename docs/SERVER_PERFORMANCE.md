# Worker measurements and capacity

Each worker measures monotonic elapsed time around its complete physics callback:
packet reads, lobby/service transitions, shared vehicle/race simulation, snapshot
encoding and result generation. Scheduled waiting between callbacks is excluded.
HTTP callbacks, heartbeat serialization and RSS collection occur outside that
physics interval. This measures callback work, including preemption within it;
it does not prove an unsaturated host or low end-to-end scheduling delay.

Two fixed 3,600-element integer buffers retain durations and timestamps. Reports
filter the last 30 wall-clock seconds, sort a temporary bounded copy, and use
nearest-rank p95/p99. A tick strictly above 16,670 microseconds is a deadline miss.
Five-second private heartbeats include counts, window length, percentiles,
maximum, misses, active cars and current process RSS. The first ready heartbeat
waits for at least 60 observed ticks; allocation still has its ten-second bound.

The native adapter reads current resident memory through macOS
`MACH_TASK_BASIC_INFO`, Windows `GetProcessMemoryInfo().WorkingSetSize`, and Linux
`/proc/self/smaps_rollup` (or the sum of `Rss` in `smaps`). Linux `statm`/`status`
are deliberately avoided because their counters may be inaccurate. Unavailable
RSS is zero, never engine heap usage or a lifetime peak. RSS collection runs
every five seconds, outside physics, and includes shared resident pages.

The production `pacific-directory serve` command requires performance headroom
for **additional room creation**. Every existing non-Closed worker must have an
authenticated observation newer than 15 seconds, at least 60 samples, current
RSS below 256,000,000 bytes and p95 strictly below 8,000 microseconds. A deadline
alert also blocks creation. This leaves a 20% p95 margin below the design's
10 ms boundary; the configured process/UDP pool cap continues to apply.
Startup, missing or stale metrics conservatively return the existing `capacity`
error. Existing joins, reconnects and running rooms remain available under their
ordinary readiness/liveness rules. An empty pool can start its first worker.
The embedded Go API defaults to legacy admission unless `RequirePerformance`
is enabled; the shipped service command always enables it.

Only authenticated, committed heartbeats update the latest numeric SQLite
observation. Admission reads these reports across overlapping supervisors under
the same freshness/validation limits; worker release removes the row. A bounded
in-memory cache retains alert edges. Structured daily operator logs include numeric reports and
one `worker_tick_deadline_alert` on entry to a complete 30-second window with at
least 5% misses. A recovery event clears that alert edge. Names, bodies, guest
identities and credentials are absent. Existing seven-day/100 MiB-per-day log
limits also cover these events; operators must collect these fixed alert codes.

```sh
python3 tools/godot.py --headless --script tests/worker_performance_tests.gd
python3 tools/godot.py --headless --script tests/native_memory_tests.gd
go -C services/directory test -race ./...
python3 tools/soak_acceptance.py --clear-road-spacing
```

The optional source soak runs eight actual clients through ten three-lap Palm Bay/Citrus
Pass races over independent real UDP proxies. Each direction adds 50±20 ms and
1% independent datagram loss, including ENet acknowledgements/retransmissions.
It checks matching standings, 80 finishes, clear-road p95 ≤0.25 m per client per
race, at least 500 clear observations per client/race, and no large racing control events.
The explicit following-gap fixture uses aligned received snapshots and ordinary
brake inputs to prevent scripted drivers remaining in contact for an entire
race. Production AI/physics, sample classification and all limits are unchanged.
Each race publishes complete client checkpoints and checks its existing limits
immediately; the full run still requires all 80 normal finishes and memory coverage.
Counts include offered datagrams later
dropped by the proxy. Racing wire intervals exclude handshake; reports separate
UDP payload bytes from IPv4+UDP overhead (28 bytes/datagram). Default lifetime
is at least 960 seconds to compare maximum observed RSS between five and fifteen
minutes against the 5% growth limit. Compare repeated-cycle peak RSS after warm-up
against the high-water mark through minute five; also report the instantaneous
five-/fifteen-minute values and retained growth. Every transition peak remains
visible. This rematch-cycle observation is separate from continuous worst-track
PERF-01. The absolute 256 MB resident budget applies throughout.

The source-only driver fixture uses the shared Medium AI, snapshot traffic
avoidance and eight explicit target-speed factors within ordinary Easy/Hard
speed ranges. Four car types remain present. This spreads the field enough to
retain the unchanged 500 clear samples per driver/race guard; no game controller,
car data, contact flags or correction threshold changes. Each proxy has its own
fixed random seed. The collector includes a final post-exit pass so the last
race's wire interval cannot disappear when all clients end together. Failures
remain in unique report folders, with coverage and accuracy recorded separately.

The build workflow exposes an optional `run_soak` manual-dispatch input and
preserves its reports even on failure. Directory integration CI downloads and
registers the matching Linux adapter before checking measured workers.

Source/native checks establish instrumentation and policy behavior. This Mac's
automated soak is a different status from the required stripped Linux export on
a documented two-vCPU x86-64 host, target Android thermal behavior, human control
feel and hosted capacity/load testing. Scheduling, CPU contention and peak
allocations between five-second RSS samples remain explicit measurement limits.

API references: [Linux RSS accuracy](https://man7.org/linux/man-pages/man5/proc_pid_statm.5.html),
[Windows process memory](https://learn.microsoft.com/en-us/windows/win32/api/psapi/nf-psapi-getprocessmemoryinfo),
[Apple resident memory structure](https://developer.apple.com/documentation/kernel/mach_task_basic_info_data_t).


The completed local two-lap run passes all eleven guards: 80 finishes with the
same eight identities and identical standings, no DNF/bot substitutions, at least
1,138 clear samples per driver/race and worst clear p95 0.0262932 m. IPv4+UDP
per-race peaks are 3,716 B/s upstream and 15,656 B/s downstream. Five-to-fifteen
minute cycle high-water growth is 0.0574%; maximum sampled RSS throughout is
171,458,560 bytes. The full 1,699.7-second run cleans up all owned processes and
proxies. [Full evidence](evidence/m5-soak-ten-two-lap.json) retains numeric window
observations, all eighty client/race correction metrics and ten wire intervals.
The preceding one-lap repeat remains failed for insufficient coverage in three
client/race cases; its accuracy, standings, wire and memory guards passed.
[Failed evidence](evidence/m5-soak-one-lap-coverage-failed.json).
Two laps increase observation time without changing physics, car/AI parameters,
contacts, speed factors, the 500-sample requirement or the 0.25 m guard.
