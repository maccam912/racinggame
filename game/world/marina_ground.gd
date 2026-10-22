class_name MarinaGround
extends RefCounted
## One continuous world-space surface puts gardens beneath the authored groves.
## The same material spans terrain, verge and distant ground without extra planes.
static var cached: ShaderMaterial

static func material(track: TrackDefinition) -> ShaderMaterial:
	if cached!=null: return cached
	var gardens := PackedVector4Array()
	var axes := PackedVector2Array()
	for region: Dictionary in CourseArt.spec(track.id).get("scenery_regions",[]):
		if region.kind!="grove": continue
		var pose := track.pose(CourseArt.original_s(track,float(region.u)),float(region.side)*float(region.setback))
		gardens.append(Vector4(pose.origin.x,pose.origin.z,float(region.depth)+9,float(region.along)+9))
		axes.append(Vector2(pose.basis.x.x,pose.basis.x.z).normalized())
	assert(gardens.size()<=16)
	var count := gardens.size()
	gardens.resize(16)
	axes.resize(16)
	cached = ShaderMaterial.new()
	cached.shader = load("res://assets/exported/shaders/marina_ground.gdshader")
	cached.set_shader_parameter("gardens",gardens)
	cached.set_shader_parameter("garden_axes",axes)
	cached.set_shader_parameter("garden_count",count)
	return cached
