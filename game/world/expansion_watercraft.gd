class_name ExpansionWatercraft
extends RefCounted
## Authored coastal silhouettes, with bounded GPU motion and planting windows.
# Site rows: canonical route distance, lateral offset, road approach distance.
const SPECS := {
	"aurora_harbor":{"kind":"icebreaker","radius":31.0,"sites":[[580,145.0,160.0]]},
	"monsoon_delta":{"kind":"river_barge","radius":25.0,"sites":[[980,145.0,160.0],[3220,265.0,100.0]]},
	"coral_causeway":{"kind":"outrigger","radius":18.0,"sites":[[1300,145.0,160.0],[2740,145.0,160.0],[5080,265.0,100.0]]},
	"container_corkscrew":{"kind":"harbor_tug","radius":27.0,"sites":[[740,145.0,160.0]]},
}

static var bounds_cache: Dictionary = {}

static func plan(world: TrackWorld) -> Array[Dictionary]:
	var sites: Array[Dictionary] = []
	if not SPECS.has(world.track.id): return sites
	var spec: Dictionary = SPECS[world.track.id]
	var sea: float = CourseArt.terrain_info[world.track.id].sea_level
	for index in range(spec.sites.size()):
		var authored: Array = spec.sites[index]
		var s := float(authored[0])
		var pose := world.track.pose(s,float(authored[1]))
		pose.origin.y = sea
		pose.basis = Basis(Vector3.UP,pose.basis.get_euler().y+.18)
		var approach := world.track.pose(s-float(authored[2])).origin
		sites.append({"kind":spec.kind,"pose":pose,"s":s,"radius":spec.radius,"approach_distance":float(authored[2]),"approach":approach,"sea_level":sea,"variant":index})
	return sites

static func protect_views(world: TrackWorld, sites: Array[Dictionary]) -> void:
	for site: Dictionary in sites:
		world.scenery_clearings.append({"center":site.pose.origin,"radius":float(site.radius)+4})
		var first: Vector3 = site.approach
		var count := ceili(first.distance_to(site.pose.origin)/24.0)
		for step in range(1,count+1):
			world.scenery_clearings.append({"center":first.lerp(site.pose.origin,step/float(count)),"radius":18.0})

static func swept_bounds(kind: String, variant_index: int) -> AABB:
	var key := kind+":"+str(variant_index)
	if bounds_cache.has(key): return bounds_cache[key]
	var points := ExpansionWatercraftArt.mesh(kind,variant_index).get_faces()
	var first := true
	var bounds := AABB()
	for step in range(65):
		var roll := Basis(Vector3.BACK,lerpf(-.025,.025,step/64.0))
		for point: Vector3 in points:
			var at := roll*point
			if first:
				bounds = AABB(at,Vector3.ZERO)
				first = false
			else: bounds = bounds.expand(at)
	bounds.position.y -= .22
	bounds.size.y += .44
	bounds = bounds.grow(.05)
	bounds_cache[key] = bounds
	return bounds

static func build(world: TrackWorld, sites: Array[Dictionary]) -> void:
	for site: Dictionary in sites:
		var node := MeshInstance3D.new()
		node.name = "Watercraft_"+str(site.kind)+"_"+str(site.variant)
		node.mesh = ExpansionWatercraftArt.mesh(site.kind,int(site.variant))
		node.transform = site.pose
		var surface := ShaderMaterial.new()
		surface.shader = load("res://assets/exported/shaders/set_piece_motion.gdshader")
		surface.set_shader_parameter("motion",8)
		surface.set_shader_parameter("motion_speed",.75)
		surface.set_shader_parameter("sway_phase",float(site.variant)*1.9)
		surface.set_shader_parameter("sway_angle",.025)
		surface.set_shader_parameter("bob_height",.22)
		surface.set_shader_parameter("animation_enabled",1.0)
		surface.set_shader_parameter("glow",.08 if float(world.art.emission)>0 else 0.0)
		node.material_override = surface
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.custom_aabb = swept_bounds(site.kind,int(site.variant))
		node.extra_cull_margin = 0
		node.visibility_range_end = 700
		node.set_meta("lod_limit",700.0)
		node.set_meta("watercraft_site",site.duplicate(true))
		node.add_to_group("scenery_motion")
		node.add_to_group("scenery_distance")
		world.add_child(node)
