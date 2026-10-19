extends SceneTree

var failures: int = 0


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error("TEST FAIL: " + message)
		failures += 1


func _initialize() -> void:
	var samples: Array[Dictionary] = []
	for index in range(20):
		samples.append({"time":index / 20.0, "position":Vector3(index * .12345, 4.35, -index * .54321), "yaw":.12 * index})
	samples.append({"time":.973456, "position":Vector3(3, 4.35, -12), "yaw":2.4})
	var hash_value := "ab".repeat(32)
	var bytes := GhostCodec.encode("palm_bay", "comet", hash_value, .973456, samples)
	check(not bytes.is_empty(), "ghost encoding")
	var decoded := GhostCodec.decode(bytes, "palm_bay", "comet", hash_value)
	check(not decoded.is_empty() and absf(decoded.time - .973456) < .000000001, "exact finish time retained")
	if not decoded.is_empty():
		check(decoded.samples[-1].position.distance_to(samples[-1].position) <= .01, "final sample position")
		check(GhostCodec.at_time(decoded, .025).position.distance_to(samples[0].position.lerp(samples[1].position, .5)) <= .01, "20 Hz interpolated ghost")
	var damaged := bytes.duplicate()
	damaged[50] ^= 1
	check(GhostCodec.decode(damaged, "palm_bay", "comet", hash_value).is_empty(), "ghost checksum corruption rejected")
	check(GhostCodec.decode(bytes, "palm_bay", "needle", hash_value).is_empty(), "ghost car compatibility")
	for length in range(bytes.size()):
		check(GhostCodec.decode(bytes.slice(0, length), "palm_bay", "comet", hash_value).is_empty(), "truncated ghost rejected")
	check(not GhostCodec.valid_id("../../escape"), "ghost path traversal rejected")
	var targets := Medals.thresholds(3098.3)
	check(targets == [79.1, 88.6, 100.5], "canonical medal rounding")
	check(Medals.award(3098.3, targets[0], true) == 0 and Medals.award(3098.3, targets[0], false) == -1, "gold tie and invalid trial")
	print("Ghost/medal fixtures: exact final time, interpolation, corruption and thresholds; failures %d" % failures)
	quit(1 if failures else 0)
