class_name TrackWorld
extends Node3D
## Graybox geometry is authored directly from the same bake used for rules/AI.

var track: TrackDefinition
var materials: Dictionary = {}
var build_stage: int = 0
var scenery_cursor: int = 0
var pending_geometry: Dictionary = {}
static var shared_sky: Sky


func material(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var key := color.to_html() + str(roughness)
	if materials.has(key):
		return materials[key]
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	materials[key] = result
	return result


func build(data: TrackDefinition) -> void:
	begin_build(data)
	while not advance_build(): pass


func begin_build(data: TrackDefinition) -> void:
	track = data
	build_stage = 0
	scenery_cursor = 0


func build_steps() -> int:
	return 4+ceili(float(int(track.length))/220.0)


func advance_build() -> bool:
	match build_stage:
		0: build_environment()
		1: build_road()
		2: build_collision()
		_:
			if scenery_cursor<int(track.length):
				for s: int in range(scenery_cursor,mini(scenery_cursor+220,int(track.length)),22):
					palm(track.pose(s,-24).origin)
					palm(track.pose(s+10,-42).origin)
					if s%66==0: palm(track.pose(s,28).origin)
				scenery_cursor += 220
			else:
				gantry()
				build_stage += 1
				return true
	build_stage += 1
	return false


func build_environment() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	if shared_sky==null:
		shared_sky = Sky.new()
		var sky_material := ProceduralSkyMaterial.new()
		sky_material.sky_top_color = Color.html("65B9EB")
		sky_material.sky_horizon_color = Color.html("B9E6ED")
		sky_material.ground_horizon_color = Color.html("B9E6ED")
		sky_material.ground_bottom_color = Color.html("31BFC1")
		shared_sky.sky_material = sky_material
	settings.sky = shared_sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.html("B9E6ED")
	settings.ambient_light_energy = 0.65
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color.html("FFF1D2")
	sun.light_energy = 1.15
	add_child(sun)
	box(Vector3(500, -1, -200), Vector3(9000, 1, 9000), Color.html("31BFC1"))


func build_road() -> void:
	pending_geometry = RouteGeometry.meshes(track,true)
	var geometry := pending_geometry
	var sand := material(Color.html("D8BD86") if track.definition.surface == "sand" else Color.html("79A269"))
	for key: String in geometry:
		var instance := MeshInstance3D.new()
		instance.mesh = geometry[key]
		var mat: StandardMaterial3D = material(Color.html("646B75")) if key == "asphalt" else material(Color.html("F5EBD3")) if key in ["walls", "markings"] else sand
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		instance.material_override = mat
		add_child(instance)


func build_collision() -> void:
	var collision := RouteCollision.new()
	for key in ["asphalt", "shoulder", "walls"]:
		collision.add_mesh(pending_geometry[key])
	add_child(collision)
	pending_geometry.clear()


func box(at: Vector3, size: Vector3, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material(color)
	node.position = at
	(parent if parent else self).add_child(node)
	return node


func palm(at: Vector3) -> void:
	var trunk := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = .20
	cylinder.bottom_radius = .38
	cylinder.height = 8
	cylinder.radial_segments = 6
	trunk.mesh = cylinder
	trunk.material_override = material(Color.html("B96344"))
	trunk.position = at + Vector3.UP * 4
	trunk.add_to_group("scenery_distance")
	add_child(trunk)
	for angle in range(0, 360, 60):
		var leaf := box(at + Vector3.UP * 8, Vector3(0.8, .18, 5), Color.html("2F6650"))
		leaf.add_to_group("scenery_distance")
		leaf.rotation_degrees = Vector3(12, angle, 0)
		leaf.position += leaf.basis.z * 1.8


func gantry() -> void:
	var root := Node3D.new()
	root.transform = track.pose(0)
	add_child(root)
	for side: float in [-1.0, 1.0]:
		box(Vector3(side * 11, 3, 0), Vector3(.65, 6, .65), Color.html("F3E4C4"), root)
	box(Vector3(0, 6, 0), Vector3(22, 1, .7), Color.html("172C40"), root)
	for x in range(-11, 11):
		box(Vector3(x + .5, 5.95, -.38), Vector3(1, .8, .06), Color.html("F5EBD3") if x % 2 == 0 else Color.html("343C49"), root)
	var label := Label3D.new()
	label.text = track.definition.name.to_upper()
	label.font_size = 80
	label.pixel_size = .012
	label.position = Vector3(0, 7.1, .0)
	label.modulate = Color.html("F5EBD3")
	label.no_depth_test = false
	root.add_child(label)
