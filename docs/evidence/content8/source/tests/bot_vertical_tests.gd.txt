extends SceneTree
## Height filtering must reject overpasses while retaining steep and banked traffic.
var cases: Array[Dictionary] = []

func _initialize() -> void:
	Catalog.load_all()
	var driver := BotDriver.new()
	var track := Catalog.tracks[6]
	var lower := CourseArt.original_s(track,0)
	var upper := CourseArt.original_s(track,.5)
	var state := racer(0,Vector3.ZERO)
	var pose := track.pose(lower)
	state.position = pose.origin+Vector3.UP*.35
	state.yaw = atan2(-pose.basis.z.x,pose.basis.z.z)
	var nearest := {"i":track.sample_index(lower),"lateral":0.0}
	var empty := driver.passing_plan(state,nearest,track,[],60)
	for delta in range(-3,4):
		var rival := racer(1,track.pose(upper+delta).origin+Vector3.UP*.35)
		var plan := driver.passing_plan(state,nearest,track,[rival],60)
		print("SKYLINE_LEVEL_CASE upper_offset=",delta," height_m=",rival.position.y-state.position.y," plan=",plan)
		assert(plan==empty,"a car on the bridge 180 m above cannot trigger a passing manoeuvre")
		cases.append({"kind":"real_skyline_crossing","offset":delta,"height_m":rival.position.y-state.position.y,"plan":plan})
	track = flat()
	state = racer(0,Vector3(0,.35,0))
	nearest = {"i":0,"lateral":0.0}
	var lead := racer(1,Vector3(0,.35,-10))
	var left := racer(2,Vector3(-3,12.35,-12))
	var right := racer(3,Vector3(3,-11.65,-12))
	assert(driver.passing_plan(state,nearest,track,[lead,left,right],40).offset==-3,"cars on other levels cannot block a free passing side")
	assert(driver.passing_plan(state,nearest,track,[right,left,lead],40).offset==-3,"height filtering preserves roster-order independence")
	left.position.y = .35
	assert(driver.passing_plan(state,nearest,track,[lead,left,right],40).offset==3,"same-level left traffic still blocks that side")
	right.position.y = .35
	assert(driver.passing_plan(state,nearest,track,[lead,left,right],40)=={"offset":0.0,"speed":19.0},"two same-level blockers still force following")
	for height: float in [-2.5,2.5]:
		lead.position.y = .35+height
		assert(driver.passing_plan(state,nearest,track,[lead],40).offset==-3,"the 2.5 m height boundary remains traffic")
	for height: float in [-2.501,2.501,-20,20]:
		lead.position.y = .35+height
		assert(driver.passing_plan(state,nearest,track,[lead],40)=={"offset":0.0,"speed":40.0})
	cases.append({"kind":"side_blockers_and_height_boundaries","passed":true})
	for grade: float in [-.24,.24]:
		for bank: float in [-12,0,12]:
			track = flat()
			track.points[1].y = grade*100
			var tangent := (track.points[1]-track.points[0]).normalized()
			track.forwards = PackedVector3Array([tangent,tangent])
			for row: Array in track.bake.samples: row[9] = deg_to_rad(bank)
			state = racer(0,RouteGeometry.point(track,0,0)+Vector3.UP*.35)
			lead = racer(1,RouteGeometry.point(track,0,0).lerp(RouteGeometry.point(track,1,0),.2)+Vector3.UP*.35)
			assert(absf(lead.position.y-state.position.y)>4.7,"fixture crosses the false absolute-Y cutoff")
			assert(driver.passing_plan(state,nearest,track,[lead],40).offset==-3,"cars ahead on steep/banked pavement remain traffic")
			lead.position.y += 12
			assert(driver.passing_plan(state,nearest,track,[lead],40)=={"offset":0.0,"speed":40.0})
			cases.append({"kind":"steep_banked_road","grade":grade,"bank_degrees":bank,"passed":true})
	# Ramp offsets are part of the actual collision surface, not the centreline tangent.
	track = flat()
	track.bake.samples[1][10] = 20.0
	state = racer(0,Vector3(0,.35,0))
	lead = racer(1,Vector3(0,4.35,-20))
	assert(driver.passing_plan(state,nearest,track,[lead],40).offset==-3,"baked ramp offset contributes to the traffic plane")
	cases.append({"kind":"ramp_surface_offset","passed":true})
	DirAccess.make_dir_recursive_absolute("res://reports")
	var file := FileAccess.open("res://reports/content8-bot-levels.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"content_hash":Compatibility.content_hash(),"cases":cases,"boundary":"Deterministic planner regression: actual Skyline crossing, physical-grade/bank/ramp geometry and both passing-side blocker paths. Complete field races are separate acceptance."},"  ")+"\n")
	file.close()
	print("BOT_ACTUAL_OVERPASS_STEEP_BANK_RAMP_TRAFFIC_SIDE_BLOCKERS_HEIGHT_BOUNDARIES_PASS")
	quit()

func racer(slot: int, at: Vector3) -> VehicleState:
	var state := VehicleState.new()
	state.slot = slot
	state.position = at
	state.velocity = Vector3.FORWARD*20
	return state

func flat() -> TrackDefinition:
	var track := TrackDefinition.new()
	track.points = PackedVector3Array([Vector3.ZERO,Vector3.FORWARD*100])
	track.forwards = PackedVector3Array([Vector3.FORWARD,Vector3.FORWARD])
	track.bake = {"samples":[[0,0,0,0,0,-1,0,0,16,0,0],[0,0,-100,0,0,-1,0,0,16,0,0]]}
	return track
