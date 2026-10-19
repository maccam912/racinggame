class_name CarVisual
extends Node3D
## Original Blender/glTF models. Rendering never supplies collision or handling.
const MODEL_IDS: Array[String] = ["comet","needle","switch","sunset"]
var chassis := Node3D.new()
var wheels: Array[Node3D] = []
var wheel_rest: Dictionary = {}
var lods: Array[Node3D] = []
var body_meshes: Array[MeshInstance3D] = []
var number_labels: Array[Label3D] = []
var surface := ShaderMaterial.new()
var ghost_surface: ShaderMaterial
var fade_surface := ShaderMaterial.new()
var applied_material: Material
var opacity: float = 1
var prior_recovery: int = 0
var recovery_anchor := Transform3D.IDENTITY
var has_presented: bool = false
var recovery_anchor_active: bool = false
var shadow: MeshInstance3D
var tire_rotation: float = 0.0
var model_id: String = "comet"
var active_lod: int = -1
var ghost: bool = false
var last_grounded: bool = true
var landing_time: float = 0.0
var visual_up := Vector3.UP

static func available(id: String) -> bool:
	var path := "res://assets/exported/cars/"+id+".glb"
	return id in MODEL_IDS and ResourceLoader.exists(path,"PackedScene") and load(path) is PackedScene

func relative_transform(node: Node3D) -> Transform3D:
	var result := node.transform
	var ancestor := node.get_parent() as Node3D
	while ancestor!=null and ancestor!=self:
		result = ancestor.transform*result
		ancestor = ancestor.get_parent() as Node3D
	return result

func build(paint: Color, id: String = "comet", slot: int = 0) -> void:
	assert(available(id),"Installation incomplete: missing car asset "+id)
	model_id = id
	add_child(chassis)
	var packed: PackedScene = load("res://assets/exported/cars/"+id+".glb")
	var model := packed.instantiate() as Node3D
	chassis.add_child(model)
	surface.shader = load("res://assets/exported/shaders/car.gdshader")
	surface.set_shader_parameter("atlas",load("res://assets/exported/textures/cars_atlas.png"))
	surface.set_shader_parameter("paint",paint)
	var stripe := Color("F5EBD3") if paint.get_luminance()<.55 else Color("343C49")
	surface.set_shader_parameter("stripe",stripe)
	fade_surface.shader = load("res://assets/exported/shaders/car_fade.gdshader")
	for key: String in ["atlas","paint","stripe"]: fade_surface.set_shader_parameter(key,surface.get_shader_parameter(key))
	applied_material = surface
	for level in range(3):
		var found: Node3D
		for node: Node3D in model.find_children("LOD*","Node3D",true,false):
			if str(node.name).begins_with("LOD%d"%level):
				found = node
				break
		assert(found!=null,"Installation incomplete: car LOD missing")
		lods.append(found)
	for node: Node3D in model.find_children("*","Node3D",true,false):
		if str(node.name).contains("_Wheel_") and not node is MeshInstance3D:
			wheels.append(node)
			wheel_rest[node] = relative_transform(node)
		if node is MeshInstance3D:
			body_meshes.append(node)
			for index in range(node.mesh.get_surface_count()): node.set_surface_override_material(index,surface)
	assert(wheels.size()==12 and body_meshes.size()==15,"Installation incomplete: car model hierarchy invalid")
	for side: float in [-1.0,1.0]:
		var label := Label3D.new()
		label.text = str(slot+1)
		label.font = load("res://assets/fonts/heading.tres")
		label.font_size = 64
		label.pixel_size = .005
		label.position = Vector3(side*({"comet":.95,"needle":.99,"switch":.90,"sunset":1.03}[id]),.46,.08)
		label.rotation.y = side*PI/2
		label.modulate = stripe
		label.outline_size = 0
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chassis.add_child(label)
		number_labels.append(label)
	shadow = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.3,4.5)
	shadow.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/exported/shaders/blob_shadow.gdshader")
	shadow.material_override = material
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.position.y = -.32
	add_child(shadow)
	choose_lod(0)

func choose_lod(level: int) -> void:
	if active_lod==level: return
	active_lod = clampi(level,0,2)
	for index in range(lods.size()): lods[index].visible = index==active_lod
	for label: Label3D in number_labels: label.visible = active_lod<2 and not ghost

func _process(_dt: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera:
		var distance := global_position.distance_to(camera.global_position)
		choose_lod(0 if distance<35 else 1 if distance<90 else 2)

func present(state: VehicleState, input: InputFrame, dt: float) -> void:
	if not state.dnf_reason.is_empty(): dt = 0
	if state.recovery_ticks>prior_recovery and state.recovery_ticks>30 and has_presented:
		recovery_anchor = transform
		recovery_anchor_active = true
	if state.recovery_ticks==0: recovery_anchor_active = false
	position = state.position
	if not has_presented: visual_up = state.ground_normal
	if state.grounded: visual_up = visual_up.lerp(state.ground_normal,1-exp(-12*dt)).normalized()
	var road_forward := state.forward().slide(visual_up).normalized()
	basis = Basis(road_forward.cross(visual_up).normalized(),visual_up,-road_forward)
	if state.recovery_ticks>30 and recovery_anchor_active: transform = recovery_anchor
	prior_recovery = state.recovery_ticks
	has_presented = true
	opacity = .75 if state.ghost_ticks>0 else 1.0
	if state.recovery_ticks>0:
		opacity = (state.recovery_ticks-30)/30.0 if state.recovery_ticks>=30 else (30-state.recovery_ticks)/30.0*.75
	opacity = clampf(opacity,0,1)
	if not ghost:
		var next: Material = fade_surface if opacity<.999 else surface
		if next!=applied_material:
			for mesh: MeshInstance3D in body_meshes:
				for index in range(mesh.mesh.get_surface_count()): mesh.set_surface_override_material(index,next)
			applied_material = next
		fade_surface.set_shader_parameter("visual_alpha",opacity)
		for label: Label3D in number_labels: label.modulate.a = opacity
	if not last_grounded and state.grounded: landing_time = .2
	last_grounded = state.grounded
	landing_time = maxf(0,landing_time-dt)
	chassis.position.y = -.12*sin(PI*landing_time/.2) if landing_time>0 else 0.0
	chassis.rotation.z = lerp_angle(chassis.rotation.z,deg_to_rad(state.steer_filter*4)*clampf(state.speed()/35,0,1),1-exp(-10*dt))
	chassis.rotation.x = lerpf(chassis.rotation.x,deg_to_rad(input.brake*2),1-exp(-10*dt))
	tire_rotation += state.velocity.dot(state.forward())*dt/.34
	for wheel: Node3D in wheels:
		var rest: Transform3D = wheel_rest[wheel]
		var steering := -deg_to_rad(state.steer_filter*25) if rest.origin.z<0 else 0.0
		wheel.global_transform = global_transform*rest*Transform3D(Basis(Vector3.UP,steering),Vector3.ZERO)
		for child: Node3D in wheel.get_children(): child.rotation.x = tire_rotation
	surface.set_shader_parameter("braking",1.0 if state.braking or input.brake>.1 or input.handbrake else 0.0)
	fade_surface.set_shader_parameter("braking",surface.get_shader_parameter("braking"))
	if ghost_surface: ghost_surface.set_shader_parameter("braking",0.0)
	shadow.visible = state.grounded and not ghost
	shadow.material_override.set_shader_parameter("opacity",opacity)
	if shadow.visible:
		var normal := state.ground_normal.normalized()
		var forward := state.forward().slide(normal).normalized()
		var right := forward.cross(normal).normalized()
		shadow.global_transform = Transform3D(Basis(right,normal,-forward),state.position-normal*.32)
	visible = opacity>.001 or ghost

func set_ghost(alpha: float) -> void:
	ghost = true
	ghost_surface = ShaderMaterial.new()
	ghost_surface.shader = load("res://assets/exported/shaders/car_ghost.gdshader")
	for parameter: String in ["atlas","paint","stripe"]: ghost_surface.set_shader_parameter(parameter,surface.get_shader_parameter(parameter))
	ghost_surface.set_shader_parameter("ghost_alpha",alpha)
	for mesh: MeshInstance3D in body_meshes:
		for index in range(mesh.mesh.get_surface_count()): mesh.set_surface_override_material(index,ghost_surface)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.hide()
	for label: Label3D in number_labels: label.hide()
