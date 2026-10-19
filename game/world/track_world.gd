class_name TrackWorld
extends Node3D
## Graybox geometry is authored directly from the same bake used for rules/AI.

var track: TrackDefinition
var materials: Dictionary = {}


func material(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var key := color.to_html() + str(roughness)
	if materials.has(key):
		return materials[key]
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	materials[key] = result
	return result


func build(data: TrackDefinition) -> void:
	track = data
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color.html("65B9EB")
	sky_material.sky_horizon_color = Color.html("B9E6ED")
	sky_material.ground_horizon_color = Color.html("B9E6ED")
	sky_material.ground_bottom_color = Color.html("31BFC1")
	sky.sky_material = sky_material
	settings.sky = sky
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
	var asphalt := SurfaceTool.new()
	var shoulder := SurfaceTool.new()
	var walls := SurfaceTool.new()
	var markings := SurfaceTool.new()
	for tool: SurfaceTool in [asphalt, shoulder, walls, markings]:
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := track.points.size()
	for i in range(n):
		var j := (i + 1) % n
		var wa: float = track.bake.samples[i][8] / 2.0
		var wb: float = track.bake.samples[j][8] / 2.0
		quad(asphalt, road_point(i, -wa), road_point(i, wa), road_point(j, wb), road_point(j, -wb))
		for side: float in [-1.0, 1.0]:
			quad(shoulder, road_point(i, side * wa), road_point(j, side * wb), road_point(j, side * (wb + 3)), road_point(i, side * (wa + 3)))
			var a := road_point(i, side * (wa + 3))
			var b := road_point(j, side * (wb + 3))
			quad(walls, a, b, b + Vector3.UP * 0.9, a + Vector3.UP * 0.9)
			# Sand/grass verge outside barriers, no colliding shortcut surface.
			quad(shoulder, a, b, road_point(j, side * (wb + 65)) - Vector3.UP * 2.5, road_point(i, side * (wa + 65)) - Vector3.UP * 2.5)
			quad(markings, road_point(i, side * (wa - 0.35)) + Vector3.UP * .015, road_point(j, side * (wb - .35)) + Vector3.UP * .015, road_point(j, side * (wb - .60)) + Vector3.UP * .015, road_point(i, side * (wa - .60)) + Vector3.UP * .015)
		if fposmod(track.distances[i], 12) < 4:
			quad(markings, road_point(i, -.09) + Vector3.UP * .018, road_point(i, .09) + Vector3.UP * .018, road_point(j, .09) + Vector3.UP * .018, road_point(j, -.09) + Vector3.UP * .018)
	add_surface(asphalt, material(Color.html("646B75")), true)
	add_surface(shoulder, material(Color.html("D8BD86") if track.definition.surface == "sand" else Color.html("79A269")), false)
	add_surface(walls, material(Color.html("F3E4C4")), true, true)
	add_surface(markings, material(Color.html("F5EBD3")), false)
	# Shoulder collision stays inside the allowed corridor; verges have no collision.
	var shoulder_collision := SurfaceTool.new()
	shoulder_collision.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(n):
		var j := (i + 1) % n
		for side: float in [-1.0, 1.0]:
			var wa: float = track.bake.samples[i][8] / 2
			var wb: float = track.bake.samples[j][8] / 2
			quad(shoulder_collision, road_point(i, side * wa), road_point(j, side * wb), road_point(j, side * (wb + 3)), road_point(i, side * (wa + 3)))
	add_collision(shoulder_collision.commit())
	for s in range(0, int(track.length), 22):
		var pose := track.pose(s, -24)
		palm(pose.origin)
		palm(track.pose(s + 10, -42).origin)
		if s % 66 == 0:
			palm(track.pose(s, 28).origin)
	gantry()


func road_point(i: int, lateral: float) -> Vector3:
	var row: Array = track.bake.samples[i]
	var point := track.points[i] + track.forwards[i].cross(Vector3.UP).normalized() * lateral
	point.y += float(row[10]) - lateral * tan(float(row[9]))
	return point


func quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.y < 0:
		normal = -normal
	for point: Vector3 in [a, b, c, a, c, d]:
		tool.set_normal(normal)
		tool.add_vertex(point)


func add_surface(tool: SurfaceTool, mat: Material, collision: bool, double_sided: bool = false) -> void:
	var mesh := tool.commit()
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	if mat is StandardMaterial3D:
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	add_child(instance)
	if collision:
		add_collision(mesh, double_sided)


func add_collision(mesh: ArrayMesh, double_sided: bool = false) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var concave: ConcavePolygonShape3D = mesh.create_trimesh_shape()
	concave.backface_collision = true
	shape.shape = concave
	body.add_child(shape)
	add_child(body)


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
	add_child(trunk)
	for angle in range(0, 360, 60):
		var leaf := box(at + Vector3.UP * 8, Vector3(0.8, .18, 5), Color.html("2F6650"))
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
