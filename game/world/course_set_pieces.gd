class_name CourseSetPieces
extends RefCounted
## Original batched 3D structures frame the new climbs and drops.

const SPECS: Dictionary = {
	"palm_bay":{"id":"SunburstCrest","u":.285,"count":3,"spacing":24,"height":15,"color":"F3CD48","trim":"F16B50"},
	"citrus_pass":{"id":"PackingSkyway","u":.345,"count":4,"spacing":18,"height":13,"color":"79C697","trim":"F3A43B"},
	"marina_lights":{"id":"HarborCranes","u":.32,"count":3,"spacing":28,"height":25,"color":"20BFC5","trim":"F3CD48"},
	"redwood_run":{"id":"TimberCrest","u":.34,"count":5,"spacing":18,"height":14,"color":"9B6D47","trim":"F5EBD3"},
	"sunstone_canyon":{"id":"CanyonRibs","u":.585,"count":6,"spacing":16,"height":18,"color":"D58C53","trim":"F0C381"},
	"pacific_summit":{"id":"SummitFlight","u":.68,"count":7,"spacing":20,"height":18,"color":"498DD3","trim":"F3CD48"}}


static func build(world: TrackWorld) -> void:
	var spec: Dictionary = SPECS[world.track.id]
	var center := CourseArt.original_s(world.track,float(spec.u))
	for index in range(int(spec.count)):
		var s := center+(index-(int(spec.count)-1)*.5)*float(spec.spacing)
		var pose := world.track.pose(s)
		pose.origin.y = RouteGeometry.point(world.track,world.track.sample_index(s),0).y
		pose.basis = Basis(Vector3.UP,pose.basis.get_euler().y)
		var node := MeshInstance3D.new()
		node.name = str(spec.id)+"_"+str(index)
		node.transform = pose
		node.set_meta("route_s",s)
		node.set_meta("clearance_m",float(spec.height)-.8)
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var half := float(world.track.bake.samples[world.track.sample_index(s)][8])*.5+6
		var height := float(spec.height)
		var color := Color.html(spec.color)
		var trim := Color.html(spec.trim)
		for side: float in [-1.0,1.0]:
			cuboid(tool,Transform3D(Basis.IDENTITY,Vector3(side*half,height*.5-1,0)),Vector3(1.3,height+2,1.6),color)
			cuboid(tool,Transform3D(Basis.IDENTITY,Vector3(side*half,2,0)),Vector3(1.7,.65,1.9),trim)
			beam(tool,Vector3(side*half,height-3,0),Vector3(side*(half-4),height,0),.8,trim)
		beam(tool,Vector3(-half,height,0),Vector3(0,height+5,0),1.4,color)
		beam(tool,Vector3(0,height+5,0),Vector3(half,height,0),1.4,color)
		beam(tool,Vector3(-half,height+1.8,0),Vector3(half,height+1.8,0),.65,trim)
		if world.track.id=="marina_lights":
			beam(tool,Vector3(-half-8,height+5,0),Vector3(half+14,height+5,0),1.2,trim)
			beam(tool,Vector3(-half,height,0),Vector3(half+14,height+5,0),.4,color)
		elif world.track.id=="citrus_pass":
			for x: float in [-6.0,0.0,6.0]:
				cuboid(tool,Transform3D(Basis(Vector3.FORWARD,.15*x),Vector3(x,height+2,0)),Vector3(2.5,2.5,2.5),trim)
		elif world.track.id=="pacific_summit":
			for side: float in [-1.0,1.0]:
				beam(tool,Vector3(side*(half-3),height+3,0),Vector3(side*(half-6),height+1,0),.6,trim)
		node.mesh = tool.commit()
		var surface := StandardMaterial3D.new()
		surface.vertex_color_use_as_albedo = true
		surface.roughness = .75
		node.material_override = surface
		node.add_to_group("scenery_distance")
		node.visibility_range_end = 700
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(node)


static func beam(tool: SurfaceTool, first: Vector3, last: Vector3, width: float, color: Color) -> void:
	var direction := last-first
	var basis := Basis.looking_at(direction.normalized(),Vector3.UP)
	cuboid(tool,Transform3D(basis,(first+last)*.5),Vector3(width,width,direction.length()),color)


static func cuboid(tool: SurfaceTool, pose: Transform3D, size: Vector3, color: Color) -> void:
	var box := BoxMesh.new()
	box.size = size
	var arrays := box.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for index: int in arrays[Mesh.ARRAY_INDEX]:
		var normal := pose.basis*normals[index]
		tool.set_normal(normal)
		tool.set_color(color*(.86+.14*maxf(0,normal.y)))
		tool.add_vertex(pose*vertices[index])
