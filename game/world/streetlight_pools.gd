class_name StreetlightPools
extends RefCounted
## Cheap night lighting follows both the banked road and its actual terrain verge.
## Forty-metre lamp spacing, local batches, no dynamic lights or frame callbacks.

static func vertex(world: TrackWorld, site: Dictionary, u: float, v: float) -> Vector3:
	var s := float(site.s)+(v-.5)*32
	var edge := float(world.track.bake.samples[world.track.sample_index(s)][8])*.5
	var lateral := float(site.side)*(edge-1)+(u-.5)*18
	var pose := world.ground_pose(s,lateral) if absf(lateral)<edge+3 else world.scenery_pose(s,lateral)
	return pose.origin+Vector3.UP*.035

static func build(world: TrackWorld) -> void:
	if world.lamp_glow_sites.is_empty(): return
	var tools: Dictionary = {}
	for site: Dictionary in world.lamp_glow_sites:
		var key := Vector2i(floori(site.at.x/112),floori(site.at.z/112))
		if not tools.has(key):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[key] = tool
		var tool: SurfaceTool = tools[key]
		for y in range(4):
			for x in range(4):
				for uv: Vector2 in [Vector2(x,y),Vector2(x+1,y),Vector2(x+1,y+1),Vector2(x,y),Vector2(x+1,y+1),Vector2(x,y+1)]:
					uv /= 4
					tool.set_uv(uv)
					tool.set_normal(Vector3.UP)
					tool.add_vertex(vertex(world,site,uv.x,uv.y))
	var surface := ShaderMaterial.new()
	surface.shader = load("res://assets/exported/shaders/lamp_pool.gdshader")
	surface.set_shader_parameter("light_color",Color("8DCFE9") if world.art.district=="city" else Color("F6C17C") if world.art.district=="market" else Color("D3C4FF") if world.art.district=="festival" else Color("E3E7C9"))
	surface.set_shader_parameter("strength",.22)
	for key: Vector2i in tools:
		var node := MeshInstance3D.new()
		node.name = "StreetlightPools_%d_%d"%[key.x,key.y]
		node.mesh = tools[key].commit()
		node.material_override = surface
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_to_group("scenery_distance")
		node.set_meta("lod_limit",120.0)
		node.visibility_range_end = 120
		world.add_child(node)
