class_name ShaderWarmup
extends Node
## Isolated material submissions during Loading, never a second racing scene.
signal completed
signal failed
var viewport := SubViewport.new()
var scene := Node3D.new()
var active: Callable
var variants: Dictionary = {}
var shader_paths: Dictionary = {}
var submissions: int = 0
var rendered_frames: int = 0
var finished: bool = false
var cancelled: bool = false
var image_size := Vector2i.ZERO
var retained_resources: Array[Resource] = []
var visible_objects: int = 0
var draw_calls: int = 0
var force_failure: bool = false # Source/native failure fixture only.

func prepare(world: TrackWorld, values: Dictionary) -> void:
	viewport.size = Vector2i(256,256)
	viewport.own_world_3d = true
	viewport.gui_disable_input = true
	viewport.audio_listener_enable_3d = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = {0:Viewport.MSAA_DISABLED,2:Viewport.MSAA_2X,4:Viewport.MSAA_4X}.get(int(values.get("msaa",0)),Viewport.MSAA_DISABLED)
	viewport.anisotropic_filtering_level = {2:Viewport.ANISOTROPY_2X,4:Viewport.ANISOTROPY_4X,8:Viewport.ANISOTROPY_8X,16:Viewport.ANISOTROPY_16X}.get(int(values.get("anisotropic",2)),Viewport.ANISOTROPY_2X)
	add_child(viewport)
	viewport.add_child(scene)
	for source: WorldEnvironment in world.find_children("*","WorldEnvironment",true,false):
		var environment := WorldEnvironment.new()
		environment.environment = source.environment.duplicate()
		environment.environment.adjustment_enabled = true
		environment.environment.adjustment_brightness = float(values.get("brightness",1))
		scene.add_child(environment)
		var sky := environment.environment.sky
		if sky!=null and sky.sky_material is ShaderMaterial:
			var sky_material := sky.sky_material as ShaderMaterial
			retained_resources.append(sky_material)
			shader_paths[sky_material.shader.resource_path] = true
			submissions += 1 # The cloned environment submits the sky to this viewport.
		break
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50,-35,0)
	sun.shadow_enabled = values.get("shadows","low")!="off"
	sun.directional_shadow_max_distance = 80
	scene.add_child(sun)
	collect(world)
	for index in range(4):
		retained_resources.append(load("res://assets/exported/cars/"+Catalog.cars[index].mesh_id+".glb"))
		var prototype := CarVisual.new()
		prototype.build(Catalog.paints[index],Catalog.cars[index].mesh_id,index)
		collect(prototype)
		for mesh: MeshInstance3D in prototype.body_meshes:
			for surface in range(mesh.mesh.get_surface_count()): mesh.set_surface_override_material(surface,prototype.fade_surface)
		prototype.fade_surface.set_shader_parameter("visual_alpha",.6)
		collect(prototype)
		prototype.set_ghost(.35)
		collect(prototype)
		prototype.free()
	for spark: bool in [false,true]:
		var mesh := QuadMesh.new()
		mesh.size = Vector2.ONE
		add_variant(mesh,RaceFeedback.particle_material(spark),true,true,false,GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var skid := PlaneMesh.new()
	skid.size = Vector2.ONE
	add_variant(skid,RaceFeedback.skid_material(),true,true,false,GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var rows := ceili(float(submissions)/8)
	var span := maxf(24,rows*3.0)
	var center := Vector3(0,0,((rows-1)*.5-3.5)*3)
	var offset := Vector3(0,span*.8,span*1.2)
	camera.size = span+6
	camera.position = center+offset
	camera.basis = Basis.looking_at(-offset,Vector3.UP)
	camera.far = maxf(100,span*4)
	sun.directional_shadow_max_distance = camera.far
	camera.current = true
	scene.add_child(camera)

func collect(source: Node) -> void:
	for node: MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
		if node.mesh==null: continue
		for surface in range(node.mesh.get_surface_count()):
			add_variant(node.mesh,node.get_active_material(surface),false,false,false,node.cast_shadow)
	for node: MultiMeshInstance3D in source.find_children("*","MultiMeshInstance3D",true,false):
		if node.multimesh==null or node.multimesh.mesh==null: continue
		var mesh: Mesh = node.multimesh.mesh
		for surface in range(mesh.get_surface_count()):
			add_variant(mesh,node.material_override if node.material_override else mesh.surface_get_material(surface),true,node.multimesh.use_colors,node.multimesh.use_custom_data,node.cast_shadow)
	# One number label populates the entire slot-glyph atlas before the grid.
	if not variants.has("slot_label"):
		for label: Label3D in source.find_children("*","Label3D",true,false):
			var copy := label.duplicate(0) as Label3D
			copy.text = "12345678"
			copy.transform = Transform3D.IDENTITY
			copy.position = cell()
			copy.show()
			scene.add_child(copy)
			variants["slot_label"] = true
			submissions += 1
			break

func cell() -> Vector3:
	return Vector3((submissions%8-3.5)*3.0,0,(submissions/8-3.5)*3.0)

func add_variant(mesh: Mesh, material: Material, instanced: bool, colors: bool, custom: bool, shadows: int) -> void:
	if material==null: return
	var formats: Array = []
	for surface in range(mesh.get_surface_count()):
		# ArrayMesh exposes the imported compressed vertex format. PrimitiveMesh
		# has a fixed format per primitive class; keep those classes distinct.
		formats.append(mesh.surface_get_format(surface) if mesh is ArrayMesh else mesh.get_class())
	var key := str(material.get_rid().get_id())+str(formats)+str([instanced,colors,custom,shadows])
	if variants.has(key): return
	variants[key] = true
	if not material in retained_resources: retained_resources.append(material)
	if material is ShaderMaterial and material.shader!=null: shader_paths[material.shader.resource_path] = true
	var bounds := mesh.get_aabb()
	var scale := 2.0/maxf(.001,maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z)))
	var at := cell()-bounds.get_center()*scale
	var node: GeometryInstance3D
	if instanced:
		var batch := MultiMeshInstance3D.new()
		batch.multimesh = MultiMesh.new()
		batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		batch.multimesh.use_colors = colors
		batch.multimesh.use_custom_data = custom
		batch.multimesh.mesh = mesh
		batch.multimesh.instance_count = 1
		batch.multimesh.set_instance_transform(0,Transform3D(Basis.from_scale(Vector3.ONE*scale),at))
		if colors: batch.multimesh.set_instance_color(0,Color.WHITE)
		if custom: batch.multimesh.set_instance_custom_data(0,Color.WHITE)
		node = batch
	else:
		var single := MeshInstance3D.new()
		single.mesh = mesh
		single.scale = Vector3.ONE*scale
		single.position = at
		node = single
	node.material_override = material
	node.cast_shadow = shadows
	scene.add_child(node)
	submissions += 1

func _ready() -> void:
	RenderingServer.frame_post_draw.connect(after_draw)

func allowed() -> bool: return not active.is_valid() or bool(active.call())

func _process(_dt: float) -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if allowed() and not finished and not cancelled else SubViewport.UPDATE_DISABLED
	if not allowed(): rendered_frames = 0

func after_draw() -> void:
	if finished or cancelled or not allowed(): return
	rendered_frames += 1
	if rendered_frames<2: return
	# Readback synchronizes submitted GPU work. It is a tiny loading-only target.
	var image := viewport.get_texture().get_image()
	visible_objects = RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME)
	draw_calls = RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	finished = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if force_failure or image==null or image.is_empty() or draw_calls<=0:
		failed.emit()
		return
	image_size = image.get_size()
	completed.emit()

func cancel() -> void:
	cancelled = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
