class_name ArcadeSpriteVariety
extends RefCounted
## Cosmetic districts change along the lap; all placements retain road clearance.

static func tree(track_id: String, fallback: String, s: float, lateral: float, length: float) -> String:
	var sector := int(s / length * 6.0) % 6
	var choices: Array = []
	match track_id:
		"palm_bay", "marina_lights", "skyline_splice":
			choices = ["palm", "coconut_palm", "fan_palm", "coastal_cypress"]
		"citrus_pass":
			choices = ["orchard", "orchard", "autumn_maple", "coastal_cypress"]
		"redwood_run":
			choices = ["redwood", "alpine_fir", "coastal_cypress", "autumn_maple"]
		"pacific_summit":
			choices = ["alpine_fir", "snow_pine", "snow_pine", "redwood"]
		"spillway_sprint":
			choices = ["shrub", "coastal_cypress", "alpine_fir"]
		"sunstone_canyon", "quarry_switchback":
			choices = ["shrub", "flowering_cactus", "grass"]
	if choices.is_empty(): return fallback
	return str(choices[(sector + int(s / 37.0) + int(absf(lateral) / 11.0)) % choices.size()])

static func props(world: TrackWorld, first: int, last: int, batches: Dictionary) -> void:
	var choices: Array = []
	match world.track.id:
		"palm_bay", "marina_lights": choices = ["lifeguard_tower", "beach_cabana"]
		"citrus_pass": choices = ["fruit_crates", "trail_cabin"]
		"redwood_run", "pacific_summit": choices = ["trail_cabin", "hoodoo_cluster"]
		"sunstone_canyon", "quarry_switchback": choices = ["hoodoo_cluster", "flowering_cactus"]
		"spillway_sprint": choices = ["hoodoo_cluster", "trail_cabin"]
	if choices.is_empty(): return
	for s in range(first + 24, last, 48):
		var sector := int(float(s) / world.track.length * 6.0)
		var id: String = choices[(sector + int(s / 80)) % choices.size()]
		var width: float = BillboardArt.rows[id].size_m[0]
		var side := -1.0 if int(s / 80) % 2 == 0 else 1.0
		var edge := float(world.track.bake.samples[world.track.sample_index(s)][8]) * .5
		var pose := world.scenery_pose(s, side * (edge + 15 + width))
		if not world.clear_of_road(pose.origin, width * .5): continue
		if RoadsidePosterArt.blocks_sightline(world.poster_sites, pose.origin): continue
		if not batches.has(id): batches[id] = [] as Array[Transform3D]
		batches[id].append(pose)
