extends SceneTree

func _initialize() -> void:
	var perf := WorkerPerformance.new()
	var empty := perf.snapshot(0)
	assert(empty.samples == 0 and empty.p95_us == 0 and not empty.full_window)
	# Thirty seconds, exactly five percent strictly beyond 16.67 ms.
	for i: int in range(1800):
		var start := i * 16667
		perf.record(start, start + (17000 if i % 20 == 0 else 5000))
	var observed := perf.snapshot(30_000_000, 8)
	assert(observed.samples == 1800 and observed.deadline_misses == 90)
	assert(observed.p95_us == 5000 and observed.p99_us == 17000 and observed.max_us == 17000)
	assert(observed.full_window and observed.window_us == 30_000_000 and observed.cars == 8)
	assert(perf.snapshot(29_999_999).full_window == false)
	assert(perf.snapshot(60_000_000).samples == 0, "Old samples expire by wall time")
	# Queue storage stays bounded; exact deadline is not an overrun.
	for i: int in range(8000): perf.record(100_000_000 + i * 16667, 100_000_000 + i * 16667 + 16670)
	observed = perf.snapshot(100_000_000 + 7999 * 16667 + 16670)
	assert(perf.timestamps.size() == 3600 and perf.count == 3600)
	assert(observed.samples == 1800 and observed.deadline_misses == 0 and observed.p99_us == 16670)
	var backwards := WorkerPerformance.new()
	backwards.record(20, 10)
	assert(backwards.snapshot(10).max_us == 0)
	print("WORKER_PERFORMANCE_PASS window=30s samples=1800 misses=90 ring=3600")
	quit()
