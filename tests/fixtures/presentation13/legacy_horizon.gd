extends RefCounted
## Frozen visual comparison helper from 5dc1197; never used by production.
static func build(world: TrackWorld) -> void:
	var low := Vector3(INF,INF,INF)
	var high := Vector3(-INF,-INF,-INF)
	for at: Vector3 in world.track.points:
		low = low.min(at)
		high = high.max(at)
	var center := (low+high)*.5
	var radius := Vector2(high.x-low.x,high.z-low.z).length()*.5+560
	var base_y := INF
	for height: float in world.terrain_grid.values(): base_y = minf(base_y,height)
	base_y -= 16
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dry: bool = world.track.id in ["sunstone_canyon","quarry_switchback"] or world.art.get("theme","") in ["desert","space"]
	var coast := world.track.id in ["palm_bay","marina_lights"]
	var tint := Color("AF8A81") if dry else Color("69898B")
	if world.art.get("expansion40",false): tint = Color.html(world.art.ground).darkened(.22)
	tint = tint.lerp(Color.html(world.art.horizon),.30)
	for index in range(44):
		# Leave the seaward side open; coastlines retain their broad ocean view.
		var angle := TAU*index/44
		if coast and cos(angle)>.15: continue
		var at := center+Vector3(cos(angle)*radius,0,sin(angle)*radius)
		at.y = base_y
		var seed := CourseLandscape.noise_at(index,0,11)
		var height := 100+seed*180+(90 if world.track.id=="pacific_summit" else 0)
		if world.art.get("theme","")=="polar": height += 110
		CourseDecor.stone(tool,at+Vector3(0,-height*.12,0),Vector3(220+seed*90,height,180+seed*80),tint,index)
	var node := MeshInstance3D.new()
	node.name = "LandscapeHorizon"
	node.mesh = tool.commit()
	var surface := StandardMaterial3D.new()
	surface.vertex_color_use_as_albedo = true
	surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override = surface
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(node)
