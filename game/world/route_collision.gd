class_name RouteCollision
extends Node3D
## Headless entrypoint: creates collision, never cameras, UI, fonts or audio.


func build(track: TrackDefinition) -> void:
	for mesh: ArrayMesh in RouteGeometry.meshes(track).values():
		add_mesh(mesh)


func add_mesh(mesh: ArrayMesh) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var concave: ConcavePolygonShape3D = mesh.create_trimesh_shape()
	concave.backface_collision = true
	shape.shape = concave
	body.add_child(shape)
	add_child(body)
