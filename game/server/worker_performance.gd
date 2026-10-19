class_name WorkerPerformance
extends RefCounted
## Monotonic callback work times over the last 30 wall-clock seconds.
## No scene, renderer, font or account dependencies. Fixed storage at 60 Hz.

const WINDOW_US := 30_000_000
const CAPACITY := 3600
const DEADLINE_US := 16_670
var timestamps := PackedInt64Array()
var durations := PackedInt64Array()
var cursor: int = 0
var count: int = 0
var first_us: int = -1
var platform: Object


func _init() -> void:
	timestamps.resize(CAPACITY)
	durations.resize(CAPACITY)
	if ClassDB.class_exists("PacificPlatform"):
		platform = ClassDB.instantiate("PacificPlatform")


func record(start_us: int, finish_us: int) -> void:
	if first_us < 0: first_us = start_us
	timestamps[cursor] = finish_us
	durations[cursor] = maxi(0, finish_us - start_us)
	cursor = (cursor + 1) % CAPACITY
	count = mini(count + 1, CAPACITY)


func snapshot(now_us: int, cars: int = 0) -> Dictionary:
	var values: Array[int] = []
	var misses := 0
	for index: int in range(count):
		if timestamps[index] > now_us or timestamps[index] <= now_us - WINDOW_US:
			continue
		values.append(durations[index])
		if durations[index] > DEADLINE_US: misses += 1
	values.sort()
	var elapsed := maxi(0, now_us - first_us) if first_us >= 0 else 0
	var rss := 0
	if is_instance_valid(platform) and platform.has_method("resident_memory_bytes"):
		rss = int(platform.call("resident_memory_bytes"))
	return {"version":1, "samples":values.size(), "window_us":mini(elapsed, WINDOW_US),
		"full_window":elapsed >= WINDOW_US, "p95_us":percentile(values, .95),
		"p99_us":percentile(values, .99), "max_us":values.back() if not values.is_empty() else 0,
		"deadline_misses":misses, "rss_bytes":rss, "cars":cars}


static func percentile(sorted: Array[int], proportion: float) -> int:
	return sorted[clampi(int(ceil(sorted.size() * proportion)) - 1, 0, sorted.size() - 1)] if not sorted.is_empty() else 0
