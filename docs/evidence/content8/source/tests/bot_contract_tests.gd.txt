extends SceneTree
const OLD_CONTENT: String = "78e8df7a34088aade409918658a3cd1d62b2a53c12b2779d52b2ac0ffcc6f078"
func racer(slot: int, lateral: float, ahead: float, speed: float = 20) -> VehicleState:
	var state := VehicleState.new()
	state.slot = slot
	state.position = Vector3(lateral,.35,-ahead)
	state.velocity = Vector3(0,0,-speed)
	return state

func _initialize() -> void:
	Catalog.load_all()
	var route := TrackDefinition.new()
	route.points = PackedVector3Array([Vector3.ZERO,Vector3.FORWARD*100])
	route.forwards = PackedVector3Array([Vector3.FORWARD,Vector3.FORWARD])
	route.bake = {"samples":[[0,0,0,0,0,-1,0,0,16,0,0],[0,0,-100,0,0,-1,0,0,16,0,0]]}
	var driver := BotDriver.new()
	var state := racer(0,0,0)
	var nearest := {"i":0,"lateral":0.0}
	var lead := racer(2,0,10)
	assert(driver.passing_plan(state,nearest,route,[lead],40).offset==-3,"equal road room uses stable slot tie break")
	state.slot = 1
	assert(driver.passing_plan(state,nearest,route,[lead],40).offset==3)
	lead.position.x = 1.5
	assert(driver.passing_plan(state,nearest,route,[lead],40).offset==-3,"choose more paved room rather than the roster's final rival")
	lead.position.x = -1.5
	assert(driver.passing_plan(state,nearest,route,[lead],40).offset==3)
	lead.position.x = 0
	var left := racer(3,-3,12)
	var right := racer(4,3,12)
	var blocked := driver.passing_plan(state,nearest,route,[lead,left,right],40)
	assert(blocked.offset==0 and blocked.speed==19,"blocked sides follow the nearest lead at one metre per second slower")
	assert(driver.passing_plan(state,nearest,route,[right,left,lead],40)==blocked,"roster order cannot alter the plan")
	assert(driver.passing_plan(state,nearest,route,[lead,left],40).offset==3,"side clearance considers other nearby cars")
	state.position.x = 3
	nearest.lateral = 3.0
	lead.position.x = 3
	assert(driver.passing_plan(state,nearest,route,[lead],40).offset==-3,"passing offsets are absolute centerline offsets, not added twice to current lateral position")
	route.bake.samples[0][8] = 8
	assert(driver.passing_plan(state,nearest,route,[lead],40).offset==0,"a narrow paved corridor cannot manufacture a passing lane")
	var folder := "user://tests/content3-"+RaceSetup.uuid()
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
	assert(cold.best("trial","palm_bay","comet")==-1 and cold.load_ghost("palm_bay","comet").is_empty(),"older records remain archived rather than compared to the new content")
	assert(FileAccess.get_file_as_bytes(old_path)==bytes and not cold.cup.compatible(Compatibility.content_hash()))
	assert(FileAccess.get_file_as_bytes(cold.store.path("cup"))==cup_bytes,"an incompatible cup is preserved without converting its results")
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder))==OK)
	print("BOT_PASSING_ROOM_TIES_CLEARANCE_CONTENT3_ARCHIVE_CUP_PRESERVATION_PASS")
	quit()
