class_name CarVisual
extends Node3D
## Editable graybox Comet. Visual shape never controls collision dimensions.

var chassis := Node3D.new()
var wheels: Array[Node3D] = []
var brake_lights: Array[MeshInstance3D] = []
var tire_rotation: float = 0.0


func build(paint: Color) -> void:
	add_child(chassis)
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = paint
	body_material.roughness = .32
	body_material.metallic = .3
	part(Vector3(0, .36, 0), Vector3(1.85, .65, 4.0), body_material)
	part(Vector3(0, .84, .2), Vector3(1.45, .64, 1.75), make_material(Color.html("203C50")))
	part(Vector3(0, 1.18, .25), Vector3(1.53, .12, 1.3), body_material)
	part(Vector3(0, .72, -1.35), Vector3(.26, .02, 1.25), make_material(Color.html("F5EBD3")))
	part(Vector3(0, .72, 1.5), Vector3(.26, .02, .9), make_material(Color.html("F5EBD3")))
	for side: float in [-1.0, 1.0]:
		part(Vector3(side * .61, .36, -2.015), Vector3(.48, .2, .035), make_material(Color.html("FFF0BA")))
		brake_lights.append(part(Vector3(side * .61, .38, 2.015), Vector3(.48, .16, .035), make_material(Color.html("A32F39"))))
		for z: float in [-1.25, 1.25]:
			var wheel := Node3D.new()
			wheel.position = Vector3(side * .91, .02, z)
			chassis.add_child(wheel)
			var tire := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = .34
			cylinder.bottom_radius = .34
			cylinder.height = .24
			cylinder.radial_segments = 12
			tire.mesh = cylinder
			tire.material_override = make_material(Color.html("222C39"))
			tire.rotation.z = PI / 2
			wheel.add_child(tire)
			var hub := MeshInstance3D.new()
			var hub_mesh := CylinderMesh.new()
			hub_mesh.top_radius = .20
			hub_mesh.bottom_radius = .20
			hub_mesh.height = .25
			hub_mesh.radial_segments = 8
			hub.mesh = hub_mesh
			hub.material_override = make_material(Color.html("F5EBD3"))
			hub.rotation.z = PI / 2
			wheel.add_child(hub)
			wheels.append(wheel)
	var shadow := MeshInstance3D.new()
	var shadow_mesh := QuadMesh.new()
	shadow_mesh.size = Vector2(2.3, 4.5)
	shadow.mesh = shadow_mesh
	shadow.rotation.x = -PI / 2
	shadow.position.y = -.32
	var shadow_material := make_material(Color(0.09, .16, .22, .3))
	shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow.material_override = shadow_material
	add_child(shadow)


func make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat


func part(at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	chassis.add_child(node)
	return node


func present(state: VehicleState, input: InputFrame, dt: float) -> void:
	position = state.position
	rotation.y = -state.yaw
	chassis.rotation.z = lerp_angle(chassis.rotation.z, deg_to_rad(state.steer_filter * 4) * clampf(state.speed() / 35, 0, 1), 1 - exp(-10 * dt))
	chassis.rotation.x = lerpf(chassis.rotation.x, deg_to_rad(input.brake * 2), 1 - exp(-10 * dt))
	tire_rotation += state.velocity.dot(state.forward()) * dt / .34
	for wheel: Node3D in wheels:
		wheel.rotation.y = -deg_to_rad(state.steer_filter * 25) if wheel.position.z < 0 else 0.0
		for child: Node3D in wheel.get_children():
			child.rotation.x = tire_rotation
	for light: MeshInstance3D in brake_lights:
		var mat: StandardMaterial3D = light.material_override
		mat.albedo_color = Color.html("FF634D") if input.brake > .1 or input.handbrake else Color.html("A32F39")
	visible = state.recovery_ticks < 30
