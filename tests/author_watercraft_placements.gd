extends SceneTree
## Author fixed boat coordinates against the revised road and actual terrain.
func _initialize() -> void: call_deferred("run")
func flat(at: Vector3) -> Vector2: return Vector2(at.x,at.z)
func run() -> void:
	Catalog.load_all()
	var geometry := load("res://tests/watercraft_geometry.gd")
	var output: Dictionary = {}
	for track: TrackDefinition in Catalog.tracks:
		if not ExpansionWatercraft.SPECS.has(track.id): continue
		var spec: Dictionary = ExpansionWatercraft.SPECS[track.id]
		var world := TrackWorld.new()
		world.build(track)
		root.add_child(world)
		var index: Dictionary = geometry.verge_index(world)
		var sea: float = CourseArt.terrain_info[track.id].sea_level
		var chosen: Array = []
		var locations: Array[Vector3] = []
		for authored: Array in spec.sites:
			var found := false
			for delta: float in [0,-100,100,-200,200,-350,350,-550,550,-800,800]:
				if found: break
				for lateral: float in [145,185,225,265]:
					if found: break
					var s := fposmod(float(authored[0])+delta,track.length)
					var at := track.pose(s,lateral).origin
					at.y = sea
					if not geometry.wet_disk(world,at,spec.radius,sea): continue
					var margin := INF
					for i in range(0,track.points.size(),2):
						var next := (i+2)%track.points.size()
						var near := Geometry2D.get_closest_point_to_segment(flat(at),flat(track.points[i]),flat(track.points[next]))
						margin = minf(margin,flat(at).distance_to(near)-float(spec.radius)-float(track.bake.samples[i][8])*.5-float(world.art.get("verge_extent",65))-4)
					if margin<=0: continue
					var blocked := false
					for prior: Vector3 in locations:
						if flat(at).distance_to(flat(prior))<2*float(spec.radius)+45: blocked = true
					for description: Dictionary in world.art.landmarks:
						var landmark := ExpansionCourseArt.landmark_site(world,description)
						if flat(at).distance_to(flat(landmark.pose.origin))<float(spec.radius)+float(landmark.radius)+12: blocked = true
					for site: Dictionary in world.hero_sites+world.poster_sites:
						var near := Geometry2D.get_closest_point_to_segment(flat(at),flat(site.approach),flat(site.pose.origin))
						if flat(at).distance_to(near)<float(spec.radius)+(54 if site.has("spanning") else 18): blocked = true
					if blocked: continue
					for approach: float in [160,100,220,300,400]:
						var eye: Vector3 = geometry.approach_eye(track,s-approach)
						var target := at+Vector3.UP*(12 if spec.kind=="outrigger" else 8 if spec.kind=="harbor_tug" else 3)
						if not geometry.terrain_view_clear(world,eye,target) or not geometry.verge_view_clear(index,eye,target): continue
						chosen.append([s,lateral,approach])
						locations.append(at)
						found = true
						break
			assert(found,"visible full wet footprint for "+track.id)
		output[track.id] = chosen
		print("AUTHORED_BOATS ",track.id," ",chosen)
		world.queue_free()
		await process_frame
	FileAccess.open("res://reports/layout15/watercraft-placements.json",FileAccess.WRITE).store_string(JSON.stringify(output,"\t")+"\n")
	quit()
