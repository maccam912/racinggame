class_name RaceFeedback
extends Node3D
## Bounded original visual effects. They never own a body, query or race rule.
class Puff:
	var position: Vector3
	var velocity: Vector3
	var age: float = 0
	var life: float
	var size: float
	var color: Color
	var kind: String
	var slot: int
class Strip:
	var transform: Transform3D
	var age: float = 0
	var length: float

var drive: RaceDrive
var mode: String = "full"
var particles: Array[Puff] = []
var batches: Dictionary = {}
var skid_batch: MultiMeshInstance3D
var marks: Dictionary = {}
var meters: Dictionary = {}
var last_tires: Dictionary = {}
var emission: Dictionary = {}
var spark_times: Array[float] = []
var elapsed: float = 0
var last_snapshot: int = -1
var feedback_cursor: int = 0
var cooldowns: Dictionary = {}
var random := RandomNumberGenerator.new()
var haptics := DrivingHaptics.new()
var warming: Array[MeshInstance3D] = []
var warm_frames: int = 3

func _ready() -> void:
	random.seed = 72531
	for kind: String in ["smoke","dust","spark"]:
		var material := ShaderMaterial.new()
		material.shader = load("res://assets/exported/shaders/feedback_particle.gdshader")
		material.set_shader_parameter("spark",kind=="spark")
		var mesh := QuadMesh.new()
		mesh.size = Vector2.ONE
		batches[kind] = make_batch(mesh,material,128 if kind=="spark" else 256)
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/exported/shaders/feedback_skid.gdshader")
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	skid_batch = make_batch(plane,material,8*640)
	for state: VehicleState in drive.session.states:
		marks[state.slot] = []
		meters[state.slot] = 0.0
	warm_materials()

func warm_materials() -> void:
	# Submit transparent geometry before GO, so first skid/recovery has no new
	# effect shader. This shares the active world; it never creates a second view.
	var quad := QuadMesh.new()
	quad.size = Vector2(.02,.02)
	var arrays := quad.surface_get_arrays(0)
	var colors := PackedColorArray()
	colors.resize(arrays[Mesh.ARRAY_VERTEX].size())
	colors.fill(Color(0,0,0,0))
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var fade: ShaderMaterial = drive.visual.fade_surface.duplicate()
	fade.set_shader_parameter("visual_alpha",0.0)
	for material: Material in [batches.smoke.material_override,batches.spark.material_override,skid_batch.material_override,fade]:
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		warming.append(node)

func make_batch(mesh: Mesh, material: Material, count: int) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.multimesh = MultiMesh.new()
	node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	node.multimesh.use_colors = true
	node.multimesh.mesh = mesh
	node.multimesh.instance_count = count
	node.multimesh.visible_instance_count = 0
	node.multimesh.custom_aabb = AABB(Vector3(-8000,-300,-8000),Vector3(16000,2000,16000))
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func cap(kind: String, slot: int) -> int:
	var own := slot==drive.local_slot
	var count := 12 if kind in ["spark","landing"] else (40 if own else 15) if kind=="smoke" else (30 if own else 10)
	return count/2 if mode=="reduced" else count if mode=="full" else 0

func spawn(kind: String, state: VehicleState, count: int = 1) -> void:
	var existing := 0
	for puff: Puff in particles:
		if puff.slot==state.slot and puff.kind==kind: existing += 1
	count = mini(count,cap(kind,state.slot)-existing)
	for index in range(maxi(0,count)):
		var puff := Puff.new()
		puff.slot = state.slot
		puff.kind = kind
		var normal := state.ground_normal.normalized()
		var side := state.forward().cross(normal).normalized()
		puff.position = state.position-state.forward()*1.45-normal*.22+side*random.randf_range(-.85,.85)
		puff.velocity = Vector3(random.randf_range(-.5,.5),random.randf_range(.5,1.0),random.randf_range(-.5,.5))
		puff.life = .6 if kind=="smoke" else .22 if kind=="spark" else .8
		puff.size = .22 if kind=="spark" else .32
		puff.color = Color("D5DDD9") if kind=="smoke" else Color("DCC294")
		if kind=="spark":
			var outward := signf(state.steer_filter)
			if absf(outward)<.1: outward = 1
			puff.position = state.position+side*outward*1.15
			puff.velocity = side*outward*random.randf_range(.8,2.4)+normal*random.randf_range(.6,2)-state.forward()*4
			puff.color = Color("F3CD48")
		if kind=="landing":
			puff.velocity = Vector3(random.randf_range(-2,2),.5,random.randf_range(-2,2))
		particles.append(puff)

func _physics_process(dt: float) -> void:
	var settings := drive.app_data.settings if drive.app_data else SettingsCatalog.defaults(OS.has_feature("mobile"))
	set_mode(str(settings.effects))
	var suspended := drive.paused and drive.network==null or drive.resume_ticks>0 or drive.result_sent
	haptics.update(drive,settings,dt,suspended)
	if suspended: return
	elapsed += dt
	if drive.network:
		for event_state: VehicleState in drive.network.feedback_since(feedback_cursor): consume(event_state)
		feedback_cursor = drive.network.feedback_sequence
	for index in range(drive.session.states.size()):
		var state: VehicleState = drive.state if index==drive.local_slot else drive.session.states[index]
		if drive.network==null: consume(state)
		if mode=="off" or not state.grounded or state.recovery_ticks>0 or state.speed()<5:
			last_tires.erase(index)
			continue
		var slip := state.drift_phase==1 or absf(state.velocity.dot(state.forward().cross(Vector3.UP)))>3
		var kind := "smoke" if slip and state.surface=="asphalt" else "dust" if state.surface!="asphalt" else ""
		if not kind.is_empty():
			var key := kind+str(index)
			emission[key] = float(emission.get(key,0))+dt*(60 if index==drive.local_slot else 20)
			if emission[key]>=1:
				spawn(kind,state,int(emission[key]))
				emission[key] = fmod(float(emission[key]),1)
		if slip and state.surface=="asphalt": add_skid(state)
		else: last_tires.erase(index)

func set_mode(value: String) -> void:
	if value==mode: return
	mode = value
	# Applying lower budgets takes effect immediately, including existing clouds.
	var counts: Dictionary = {}
	for index in range(particles.size()-1,-1,-1):
		var puff := particles[index]
		var key := puff.kind+str(puff.slot)
		counts[key] = int(counts.get(key,0))+1
		if counts[key]>cap(puff.kind,puff.slot): particles.remove_at(index)
	if mode=="off":
		for slot: int in marks:
			marks[slot].clear()
			meters[slot] = 0.0
		last_tires.clear()
	if is_instance_valid(skid_batch): advance(0,drive.camera.global_basis)

func consume(state: VehicleState) -> void:
	for event: String in state.events:
		if event not in ["wall","land"]: continue
		var key := event+str(state.slot)
		if elapsed<float(cooldowns.get(key,-1)): continue
		cooldowns[key] = elapsed+(.15 if event=="wall" else .5)
		if event=="wall":
			if state.slot==drive.local_slot: drive.camera.impact()
			while not spark_times.is_empty() and spark_times[0]<=elapsed-1: spark_times.pop_front()
			if spark_times.size()<8:
				spark_times.append(elapsed)
				spawn("spark",state,cap("spark",state.slot))
		else: spawn("landing",state,cap("landing",state.slot))

func add_skid(state: VehicleState) -> void:
	var normal := state.ground_normal.normalized()
	var forward := state.forward().slide(normal).normalized()
	var right := forward.cross(normal).normalized()
	var center := state.position-forward*1.45-normal*.325
	if not last_tires.has(state.slot):
		last_tires[state.slot] = center
		return
	var from: Vector3 = last_tires[state.slot]
	var length := from.distance_to(center)
	if length<(.7 if mode=="reduced" else .35): return
	last_tires[state.slot] = center
	if length>5: return # Teleports never draw a strip across the world.
	var direction := (center-from).slide(normal).normalized()
	var across := normal.cross(direction).normalized()
	for side: float in [-.78,.78]:
		var strip := Strip.new()
		strip.transform = Transform3D(Basis(across*.24,normal,direction*(length+.035)),(from+center)*.5+right*side)
		strip.length = length
		marks[state.slot].append(strip)
		meters[state.slot] = float(meters[state.slot])+length
	while meters[state.slot]>200 or marks[state.slot].size()>640:
		var oldest: Strip = marks[state.slot].pop_front()
		meters[state.slot] = maxf(0,float(meters[state.slot])-oldest.length)

func _process(dt: float) -> void:
	if warm_frames>0:
		for node: MeshInstance3D in warming:
			node.global_transform = Transform3D(drive.camera.global_basis,drive.state.position+drive.state.forward()*2+Vector3.UP*.8)
		warm_frames -= 1
		if warm_frames==0:
			for node: MeshInstance3D in warming: node.queue_free()
			warming.clear()
	if drive.paused and drive.network==null or drive.resume_ticks>0: return
	advance(dt,drive.camera.global_basis)

func advance(dt: float, camera_basis: Basis) -> void:
	var counts := {"smoke":0,"dust":0,"spark":0}
	for index in range(particles.size()-1,-1,-1):
		var puff := particles[index]
		puff.age += dt
		if puff.age>=puff.life:
			particles.remove_at(index)
			continue
		puff.position += puff.velocity*dt
		if puff.kind=="spark": puff.velocity.y -= 8*dt
		var kind := "dust" if puff.kind=="landing" else puff.kind
		var node: MultiMeshInstance3D = batches[kind]
		var at: int = counts[kind]
		if at>=node.multimesh.instance_count: continue
		var size := puff.size*(1+puff.age*(.2 if kind=="spark" else 2.5))
		var basis := camera_basis.scaled(Vector3(size,size*(2 if kind=="spark" else 1),size))
		node.multimesh.set_instance_transform(at,Transform3D(basis,puff.position))
		var color := puff.color
		color.a = pow(1-puff.age/puff.life,1.4)*(.8 if kind=="spark" else .5)
		node.multimesh.set_instance_color(at,color)
		counts[kind] += 1
	for kind: String in counts: batches[kind].multimesh.visible_instance_count = counts[kind]
	var at := 0
	for slot: int in marks:
		for index in range(marks[slot].size()-1,-1,-1):
			var strip: Strip = marks[slot][index]
			strip.age += dt
			if strip.age>=15:
				meters[slot] = maxf(0,float(meters[slot])-strip.length)
				marks[slot].remove_at(index)
				continue
			skid_batch.multimesh.set_instance_transform(at,strip.transform)
			skid_batch.multimesh.set_instance_color(at,Color(1,1,1,.45*minf(1,(15-strip.age)/3)))
			at += 1
	skid_batch.multimesh.visible_instance_count = at

func _exit_tree() -> void: haptics.stop()
