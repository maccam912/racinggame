# Finish delivery during retirement

Retirement is an operator/private-service state. Clients cannot request it.
Fresh admissions are rejected; existing reconnect tokens retain their ordinary
reservation checks. A race already set up, including Grid, continues. Lobby
transitions and automatic starts stop, so Ready/Return/Start cannot create a
rematch during retirement.

When that race reaches its normal result, the worker queues the same reliable
authoritative rows and keeps polling ENet for five seconds. This drains queued
fragments and permits retransmission before exit. The timer is anchored once;
repeated private retirement responses cannot extend it. Active retirement is
bounded to ten wall-clock minutes. An idle worker exits immediately, and an
unfinished race at the deadline receives no invented finish or saved result.
The ordinary empty-worker and liveness limits remain independent.

The original code quit at the start of the tick after `result_sent`, before the
queued message reached `WirePeer.poll()`. The separate-process reproduction
retains the failed outcome: the authority logged results but neither client
received rows. The repaired fixture checks eight real clients and a 1,952-byte
fragmented result under 75±30 ms one-way delay and 3% UDP loss. It checks active
advance, identical rows, late-admission refusal and exactly one race despite all
clients requesting Return/Ready/Start.

The fixture forces a **synthetic** finish to isolate transport/lifetime ordering.
It initializes no profile and does not establish genuine finish times, handling,
progress or local record acceptance. Ordinary full races have separate evidence.
Five seconds is a bounded delivery opportunity, not a guarantee under arbitrary
outage, process kill, packet loss or host failure.

```sh
python3 tools/godot.py --headless --script tests/retirement_tests.gd
python3 tools/retirement_integration.py
```

The worker-side drain behavior is distinct from supervisor crash recovery,
operator rollout commands, image deployment and hosted cross-play acceptance.
Those must keep the old private service alive long enough to drain its workers;
immediately killing the supervisor's child context cannot provide this grace.
