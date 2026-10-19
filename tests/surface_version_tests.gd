extends SceneTree

const OLD_CONTENT: String = "4899e636e87a2e0dbda39be146a526c4f1b3be608fec9411da2a92ca17f5fbc3"

func _initialize() -> void: call_deferred("run")

func original_s(track: TrackDefinition, u: float) -> float:
	for i in range(track.points.size()):
		var next := (i+1)%track.points.size()
		var lo := float(track.bake.samples[i][7])
		var hi := float(track.bake.samples[next][7])
		if hi<lo: hi += 1
		var target := u+1 if u<lo else u
		if target>=lo and target<hi:
			var end := track.distances[next] if next>0 else track.length
			return lerpf(track.distances[i],end,(target-lo)/(hi-lo))
	assert(false,"every original coordinate belongs to a route segment")
	return 0

func run() -> void:
	Catalog.load_all()
	assert(Catalog.rules.content_version==4 and Catalog.rules.protocol_version==5 and NetCodec.PROTOCOL==5)
	for track: TrackDefinition in Catalog.tracks:
		for u: float in [.00001,.249,.5,.6999,.7001,.8999,.9001,.99999]:
			var s := original_s(track,u)
			assert(absf(track.original_u(s)-u)<.000001,"start rotation and original seam preserve authored coordinates")
			var expected: String = "sand" if track.id=="pacific_summit" and u>=.7 and u<.9 else track.definition.surface
			assert(track.shoulder_surface(s)==expected)
	var track := Catalog.tracks[5]
	var scene := Node3D.new()
	var collision := RouteCollision.new()
	collision.build(track)
	scene.add_child(collision)
	root.add_child(scene)
	await physics_frame
	await physics_frame
	for u: float in [.6999,.7001,.72,.8,.8999,.9001]:
		var s := original_s(track,u)
		var i := track.sample_index(s)
		var next := (i+1)%track.points.size()
		var weight := (s-track.distances[i])/(track.distances[next]-track.distances[i])
		for side: float in [-1.0,0.0,1.0]:
			var lateral := side*(float(track.bake.samples[i][8])/2+1.5)
			var state := VehicleState.new()
			var pose := track.pose(s,lateral)
			state.position = pose.origin+Vector3.UP*.35
			state.position.y = lerpf(RouteGeometry.point(track,i,lateral).y,RouteGeometry.point(track,next,lateral).y,weight)+.35
			var query := WorldQuery.new(scene.get_world_3d(),track,s)
			var ground := query.ground(state)
			var expected := "asphalt" if side==0 else "sand" if u>=.7 and u<.9 else "grass"
			assert(ground.supported and ground.surface==expected,"real ground probes keep paving asphalt and apply the correct shoulder on both sides")
			query = null
	var before := var_to_bytes(RouteGeometry.meshes(track).shoulder.surface_get_arrays(0))
	var rendered := CourseRoadMesh.shoulders(track)
	assert(rendered.has("sand") and rendered.has("grass") and rendered.size()==2)
	for mesh: ArrayMesh in rendered.values():
		var arrays := mesh.surface_get_arrays(0)
		for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]: assert(normal.y>.98,"both rendered shoulders face upward")
	assert(before==var_to_bytes(RouteGeometry.meshes(track).shoulder.surface_get_arrays(0)),"surface-colored rendering cannot deform collision")
	scene.queue_free()
	await process_frame
	var folder := "user://tests/content4-"+RaceSetup.uuid()
	var data := AppData.new(folder,false)
	var old_key := "trial:palm_bay:comet:"+OLD_CONTENT
	data.records.times[old_key] = {"time":43.5}
	assert(data.store.save_component("records",data.records)==OK)
	var samples: Array[Dictionary] = [{"time":0.0,"position":Vector3.ZERO,"yaw":0.0},{"time":.05,"position":Vector3.FORWARD,"yaw":0.0},{"time":.1,"position":Vector3.FORWARD*2,"yaw":0.0}]
	var bytes := GhostCodec.encode("palm_bay","comet",OLD_CONTENT,.1,samples)
	var old_path := data.ghost_path("palm_bay","comet").get_base_dir().path_join(OLD_CONTENT+".bin")
	DirAccess.make_dir_recursive_absolute(old_path.get_base_dir())
	var file := FileAccess.open(old_path,FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	assert(data.start_cup()==OK)
	data.cup.data.content_hash = OLD_CONTENT
	assert(data.store.save_component("cup",data.cup.data)==OK)
	var cup_bytes := FileAccess.get_file_as_bytes(data.store.path("cup"))
	var cold := AppData.new(folder,false)
	assert(Compatibility.content_hash()!=OLD_CONTENT and cold.records.times[old_key].time==43.5)
	assert(cold.best("trial","palm_bay","comet")==-1 and cold.load_ghost("palm_bay","comet").is_empty())
	assert(FileAccess.get_file_as_bytes(old_path)==bytes and not cold.cup.compatible(Compatibility.content_hash()))
	assert(FileAccess.get_file_as_bytes(cold.store.path("cup"))==cup_bytes)
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder))==OK)
	print("CONTENT4_ORIGINAL_COORDINATE_SAND_GRASS_ASPHALT_BOTH_SHOULDERS_COLLISION_UNCHANGED_CONTENT3_ARCHIVES_PASS")
	quit()
