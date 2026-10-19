class_name NetworkQuality
extends RefCounted
## Five-second application delivery window. Counts every decoded snapshot before
## presentation coalescing; the server emits one snapshot every three ticks.
const WINDOW_MS: int = 5000
const PERIOD_MS: int = 50
var race: int = -1
var last_sequence: int = -1
var last_arrival: int = 0
var snapshots: Array[Dictionary] = []
var pongs: Array[Dictionary] = []

func reset(race_value: int) -> void:
	race = race_value
	last_sequence = -1
	last_arrival = 0
	snapshots.clear()
	pongs.clear()

func observe_pong(milliseconds: float, now: int = Time.get_ticks_msec()) -> void:
	if not is_finite(milliseconds) or milliseconds<0 or milliseconds>20000: return
	pongs.append({"at":now,"rtt":milliseconds})
	while pongs.size()>16: pongs.pop_front()

func observe_snapshot(race_value: int, tick: int, now: int = Time.get_ticks_msec()) -> void:
	if race!=race_value: reset(race_value)
	var sequence_value: int = tick/3
	if sequence_value<0: return
	if sequence_value<=last_sequence:
		for entry: Dictionary in snapshots:
			if int(entry.sequence)==sequence_value: entry.received = true
		return
	var begin := sequence_value if last_sequence<0 else maxi(last_sequence+1,sequence_value-99)
	for index in range(begin,sequence_value+1):
		snapshots.append({"sequence":index,"at":now-(sequence_value-index)*PERIOD_MS,"received":index==sequence_value})
	last_sequence = sequence_value
	last_arrival = now
	prune(now)

func prune(now: int) -> void:
	snapshots = snapshots.filter(func(entry: Dictionary) -> bool: return now-int(entry.at)<WINDOW_MS)
	while snapshots.size()>100: snapshots.pop_front()
	pongs = pongs.filter(func(entry: Dictionary) -> bool: return now-int(entry.at)<WINDOW_MS)

func measure(now: int = Time.get_ticks_msec(), active: bool = true) -> Dictionary:
	prune(now)
	var tail := mini(100,maxi(0,(now-last_arrival-100)/PERIOD_MS)) if active and last_sequence>=0 else 0
	var expected: int = tail
	var received: int = 0
	for entry: Dictionary in snapshots:
		if int(entry.sequence)<=last_sequence+tail-100: continue
		expected += 1
		if entry.received: received += 1
	var loss_percent := 100.0*(expected-received)/expected if expected>0 and active else 0.0
	var rtt_mean: float = 0
	for entry: Dictionary in pongs: rtt_mean += float(entry.rtt)/pongs.size()
	# A full second of delivery evidence avoids a startup one-packet percentage.
	var loss_level := 2 if loss_percent>=8 and expected>=20 else 1 if loss_percent>=3 and expected>=20 else 0
	var level := maxi(loss_level,2 if rtt_mean>=250 else 1 if rtt_mean>=150 else 0) if active else 0
	return {"rtt_ms":rtt_mean,"rtt_available":not pongs.is_empty(),"loss_percent":loss_percent,"delivery_samples":expected,"level":level,"window_seconds":5}
