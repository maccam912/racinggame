extends SceneTree
## Developer-only pre-art behavioral record. One shared 60 Hz step per movie frame.
const CASES: Array[Dictionary] = [
	{"id":"acceleration","title":"Comet / full throttle from rest","seconds":8,"speed":0.0},
	{"id":"bend_25","title":"80 m radius bend / 25 m/s entry","seconds":8,"speed":25.0},
	{"id":"bend_40","title":"80 m radius bend / 40 m/s entry","seconds":8,"speed":40.0},
	{"id":"bend_50","title":"80 m radius bend / 50 m/s entry","seconds":8,"speed":50.0},
	{"id":"slide","title":"Short scripted handbrake slide / grip restoration","seconds":5,"speed":32.0},
	{"id":"wall","title":"15 degree wall approach / sustained scrape","seconds":5,"speed":40.0},
	{"id":"bump","title":"Rear contact / shared two-car resolution","seconds":5,"speed":30.0},
	{"id":"jump","title":"Pacific Summit / explicit crest launch and landing","seconds":5,"speed":45.0},
	{"id":"touch","title":"Touch steering plus brake / scripted pointer path","seconds":7,"speed":30.0}]
var results: Array[Dictionary] = []

func _initialize() -> void: call_deferred("run")

func oval() -> TrackDefinition:
	var track := TrackDefinition.new()
	track.id = "reference_oval"
	track.definition = {"surface":"grass","ramp_markers":[],"name":"80 m reference bend"}
	var points := PackedVector3Array()
	for index in range(201): points.append(Vector3(0,4,-index*2))
	for corner in range(4):
		var center: Vector2 = [Vector2(80,-400),Vector2(400,-400),Vector2(400,0),Vector2(80,0)][corner]
		var start := PI+corner*PI/2
		for index in range(1,64 if corner==3 else 65):
			var angle := start+index*PI/128
			points.append(Vector3(center.x+80*cos(angle),4,center.y+80*sin(angle)))
		if corner==0:
			for index in range(1,161): points.append(Vector3(80+index*2,4,-480))
		elif corner==1:
			for index in range(1,201): points.append(Vector3(480,4,-400+index*2))
		elif corner==2:
			for index in range(1,161): points.append(Vector3(400-index*2,4,80))
	track.points = points
	track.bake = {"samples":[],"gates":[],"ai_speeds":{}}
	var distance: float = 0
	for index in range(points.size()):
		if index>0: distance += points[index-1].distance_to(points[index])
		track.distances.append(distance)
		var forward := (points[(index+1)%points.size()]-points[posmod(index-1,points.size())]).normalized()
		track.forwards.append(forward)
		track.bake.samples.append([points[index].x,4,points[index].z,forward.x,0,forward.z,0,0,18,0,0])
	track.length = distance+points[-1].distance_to(points[0])
	for car: CarDefinition in Catalog.cars:
		var speeds: Array[float] = []
		speeds.resize(points.size())
		speeds.fill(car.top_speed*.96)
		track.bake.ai_speeds[car.id] = speeds
	for s in range(0,int(track.length),100):
		var pose := track.pose(s)
		track.bake.gates.append({"s":s,"position":[pose.origin.x,4,pose.origin.z],"forward":[-pose.basis.z.x,0,-pose.basis.z.z],"recovery":[pose.origin.x,4,pose.origin.z]})
	return track

func run() -> void:
	Catalog.load_all()
	DrivingInput.register_defaults()
	Engine.max_fps = 0
	root.size = Vector2i(1280,720)
	for description: Dictionary in CASES: await capture_case(description)
	DirAccess.make_dir_recursive_absolute("res://reports")
	var file := FileAccess.open("res://reports/graybox-reference.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"content_hash":Compatibility.content_hash(),"physics_hz":60,"movie_fps":60,"reference_seed":104729,"car":"comet","cases":results,"boundaries":["Scripted offline-rendered shared-controller behavior, not human playtesting or frame-time evidence","Touch pointer paths exercise TouchDriving/DrivingInput; not physical-device ergonomics","Graybox capture before M4 models/scenery/audio"]},"  ")+"\n")
	file.close()
	print("GRAYBOX_REFERENCE_RECORDINGS_PASS")
	quit()

func capture_case(description: Dictionary) -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var track: TrackDefinition = Catalog.tracks[5] if description.id=="jump" else oval()
	var world := GrayboxTrackWorld.new()
	world.build(track)
	scene.add_child(world)
	var start: float = 370.0 if str(description.id).begins_with("bend") or description.id=="touch" else 80.0
	if description.id=="jump": start = fposmod(float(track.definition.ramp_markers[0])*track.length-track.start_sample*2,track.length)-18
	var pose := track.pose(start,9 if description.id=="wall" else -4 if description.id=="slide" else 0)
	var state := VehicleState.new()
	state.position = pose.origin+Vector3.UP*.35
	state.yaw = atan2(-pose.basis.z.x,pose.basis.z.z)+(deg_to_rad(15) if description.id=="wall" else 0)
	state.velocity = state.forward()*float(description.speed)
	state.route_s = start
	for index in range(track.bake.gates.size()):
		if track.bake.gates[index].s<=start: state.last_gate = index
	var query := WorldQuery.new(scene.get_world_3d(),track,start)
	var visual := GrayboxCarVisual.new()
	visual.build(Catalog.paints[0])
	scene.add_child(visual)
	var camera := ChaseCamera.new()
	camera.far = 3000
	camera.reduce_motion = true
	scene.add_child(camera)
	camera.current = true
	var layer := CanvasLayer.new()
	scene.add_child(layer)
	var label := Label.new()
	label.position = Vector2(22,18)
	label.add_theme_font_override("font",load("res://assets/fonts/Barlow-SemiBold.ttf"))
	label.add_theme_font_size_override("font_size",21)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("172c40")
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	label.add_theme_stylebox_override("normal",style)
	layer.add_child(label)
	var touch := TouchDriving.new()
	layer.add_child(touch)
	touch.visible = description.id=="touch"
	var input := DrivingInput.new()
	input.attach_touch(touch)
	var driver := BotDriver.new()
	driver.difficulty = 2
	var rival: VehicleState
	var rival_query: WorldQuery
	var rival_visual: GrayboxCarVisual
	if description.id=="bump":
		rival = VehicleState.new()
		rival.slot = 1
		rival.position = track.pose(start+8).origin+Vector3.UP*.35
		rival.yaw = state.yaw
		rival.velocity = rival.forward()*20
		rival_query = WorldQuery.new(scene.get_world_3d(),track,start+8)
		rival_visual = GrayboxCarVisual.new()
		rival_visual.build(Catalog.paints[4])
		scene.add_child(rival_visual)
	SettingsRuntime.apply(scene,SettingsCatalog.defaults(false))
	await physics_frame
	await physics_frame
	var initial := {"position":[state.position.x,state.position.y,state.position.z],"yaw":state.yaw,"speed":state.speed(),"route_s":start}
	var first_frame := Engine.get_frames_drawn()
	var maximum: float = 0
	var air_ticks: int = 0
	var event_counts: Dictionary = {}
	var drift_ticks: int = 0
	var frames: int = int(description.seconds)*60
	for tick in range(frames):
		var seconds := tick/60.0
		var frame := driver.sample(state,Catalog.cars[0],track,query)
		if description.id=="acceleration": frame = InputFrame.make(0,1)
		elif str(description.id).begins_with("bend"):
			frame.throttle = clampf((float(description.speed)-state.speed())/4+.08,0,1)
			frame.brake = clampf((state.speed()-float(description.speed))/4,0,1)
		elif description.id=="slide":
			if seconds<.5: frame = InputFrame.make(0,.3)
			elif seconds<1.0: frame = InputFrame.make(.45,.3,0,true)
			elif seconds<1.8: frame = InputFrame.make(-.4,.15)
		elif description.id=="wall": frame = InputFrame.make(.12,.6)
		elif description.id=="bump": frame = InputFrame.make(0,.3)
		elif description.id=="touch":
			var steering: Rect2 = touch.controls.steer
			if tick==0: touch.pointer_down(101,steering.get_center())
			touch.pointer_move(101,steering.get_center()+Vector2(frame.steer*70*touch.unit,0))
			if tick==60: touch.pointer_down(102,touch.controls.brake.get_center())
			if tick==120: touch.pointer_up(102)
			frame = input.sample(true,touch)
		VehicleSim.step(state,frame,Catalog.cars[0],query)
		ProgressTracker.safety(state,frame,track,query)
		if rival:
			VehicleSim.step(rival,InputFrame.make(),Catalog.cars[0],rival_query)
			CarContact.resolve([state,rival],[query,rival_query])
			rival_visual.present(rival,InputFrame.make(),1.0/60)
		visual.present(state,frame,1.0/60)
		camera.follow(state,1.0/60)
		maximum = maxf(maximum,state.speed())
		if not state.grounded: air_ticks += 1
		if state.drift_phase==1: drift_ticks += 1
		for event: String in state.events: event_counts[event] = int(event_counts.get(event,0))+1
		label.text = "DEV REFERENCE · "+description.title+"\n%5.2f s · %.2f m/s · %.1f mph\nsteer %+.2f   throttle %.2f   brake %.2f   handbrake %s\ngrounded %s   drift %d   events %s"%[seconds,state.speed(),state.speed()*2.236936,frame.steer,frame.throttle,frame.brake,str(frame.handbrake),str(state.grounded),state.drift_phase,", ".join(state.events)]
		await process_frame
	results.append({"id":description.id,"title":description.title,"start_frame":first_frame,"frames":frames,"initial":initial,"track":track.id,"maximum_speed_mps":maximum,"airborne_ticks":air_ticks,"drift_ticks":drift_ticks,"events":event_counts})
	if description.id=="wall": assert(event_counts.get("wall",0)>0)
	if description.id=="bump": assert(event_counts.get("bump",0)>0)
	if description.id=="jump": assert(event_counts.get("jump",0)==1 and event_counts.get("land",0)==1)
	if description.id=="slide": assert(drift_ticks>0 and state.drift_phase!=1 and event_counts.get("wall",0)==0)
	input = null
	query = null
	rival_query = null
	scene.queue_free()
	for index in range(3): await process_frame
