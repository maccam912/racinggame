class_name ExpansionRoadsideLife
extends RefCounted
## Three recognizable roadside prop types per course; locally batched and bounded.
const KINDS := {
	"glacier_ridge":["weather_station","rescue_sled","fuel_locker"],
	"aurora_harbor":["harbor_catch","fjord_buoy","fuel_locker"],
	"alpine_meadow":["ski_rack","weather_station","rescue_sled"],
	"frostbite_fjord":["fjord_buoy","weather_station","harbor_catch"],
	"tundra_pipeline":["fuel_locker","rescue_sled","weather_station"],
	"rainforest_ruins":["stone_idol","trail_camp","coffee_crates"],
	"monsoon_delta":["river_gauge","fishing_rack","trail_camp"],
	"coral_causeway":["surf_rack","fishing_rack","trail_camp"],
	"mangrove_maze":["fishing_rack","river_gauge","stone_idol"],
	"cloudforest_climb":["coffee_crates","trail_camp","stone_idol"],
	"sakura_ring":["cycle_rack","wayside_shrine","stone_lantern"],
	"bamboo_gorge":["bamboo_cart","stone_lantern","wayside_shrine"],
	"lantern_market":["market_cart","cycle_rack","stone_lantern"],
	"terrace_touge":["tea_baskets","bamboo_cart","wayside_shrine"],
	"temple_coast":["stone_lantern","wayside_shrine","tea_baskets"],
	"saltflat_velocity":["timing_booth","survey_tripod","weather_probe"],
	"dune_serpent":["water_tank","shade_shelter","survey_tripod"],
	"oasis_citadel":["shade_shelter","water_tank","timing_booth"],
	"copper_mesa":["core_samples","survey_tripod","weather_probe"],
	"storm_chase":["weather_probe","water_tank","survey_tripod"],
	"steelworks_sprint":["steel_rack","service_cabinet","cargo_pallet"],
	"container_corkscrew":["cargo_pallet","tire_stack","service_cabinet"],
	"neon_underpass":["bus_shelter","snack_cart","service_cabinet"],
	"windfarm_run":["service_cabinet","steel_rack","tire_stack"],
	"festival_speedway":["snack_cart","tire_stack","bus_shelter"],
	"lunar_freight":["cargo_pod","antenna_dish","rover_battery"],
	"orbital_gardens":["hydroponic_tray","survey_beacon","coolant_station"],
	"crystal_chasm":["survey_beacon","rover_battery","antenna_dish"],
	"mars_badlands":["rover_battery","survey_beacon","cargo_pod"],
	"reactor_rift":["coolant_station","antenna_dish","cargo_pod"]
}

static func plan(world: TrackWorld) -> Array[Dictionary]:
	var sites: Array[Dictionary] = []
	var landmarks: Array[Dictionary] = []
	for description: Dictionary in world.art.landmarks: landmarks.append(ExpansionCourseArt.landmark_site(world,description))
	for s in range(95,int(world.track.length),180):
		var seed := CourseLandscape.noise_at(s,0,53)
		var side := -1.0 if int(s/180)%2==0 else 1.0
		var edge := float(world.track.bake.samples[world.track.sample_index(s)][8])*.5
		var lateral := side*(edge+16+seed*14)
		var pose := world.scenery_pose(s,lateral)
		if not world.clear_of_road(pose.origin,7.5) or not world.decoration_allowed(pose.origin,7.5): continue
		if not landmark_clear(landmarks,pose.origin,world.track.pose(s-36).origin): continue
		if RoadsidePosterArt.blocks_sightline(world.poster_sites,pose.origin): continue
		if world.art.water and pose.origin.y<float(CourseArt.terrain_info[world.track.id].sea_level)+1: continue
		var facing := world.track.pose(s).origin-pose.origin
		facing.y = 0
		pose.basis = Basis.looking_at(facing.normalized(),Vector3.UP)
		var kinds: Array = KINDS[world.track.id]
		var kind: String = kinds[sites.size()%kinds.size()]
		sites.append({"kind":kind,"pose":pose,"s":s,"lateral":lateral,"radius":7.5})
		world.scenery_clearings.append({"center":pose.origin,"radius":10.5,"roadside_life_s":s})
	return sites

static func landmark_clear(landmarks: Array[Dictionary], at: Vector3, approach: Vector3) -> bool:
	var first := Vector2(approach.x,approach.z)
	var last := Vector2(at.x,at.z)
	var line := last-first
	for landmark: Dictionary in landmarks:
		var center := Vector2(landmark.pose.origin.x,landmark.pose.origin.z)
		if center.distance_to(last)<float(landmark.radius)+11.5: return false
		var fraction := clampf((center-first).dot(line)/line.length_squared(),0,1)
		if center.distance_to(first+line*fraction)<float(landmark.radius)+3: return false
	return true

static func protect_heroes(world: TrackWorld) -> void:
	var retained: Array[Dictionary] = []
	for site: Dictionary in world.decor_sites:
		if ExpansionSetPieces.blocks_sightline(world.hero_sites,site.pose.origin): continue
		var clear := true
		for hero: Dictionary in world.hero_sites:
			for clearing: Dictionary in hero.clearings:
				var delta: Vector3 = site.pose.origin-clearing.center
				if Vector2(delta.x,delta.z).length()<float(clearing.radius)+float(site.radius): clear = false
		if clear: retained.append(site)
	world.decor_sites = retained
	var retained_distances: Array[int] = []
	for site: Dictionary in retained: retained_distances.append(int(site.s))
	var clearings: Array[Dictionary] = []
	for clearing: Dictionary in world.scenery_clearings:
		if not clearing.has("roadside_life_s") or int(clearing.roadside_life_s) in retained_distances: clearings.append(clearing)
	world.scenery_clearings = clearings

static func build(world: TrackWorld) -> void:
	var buckets: Dictionary = {}
	for site: Dictionary in world.decor_sites:
		var at: Vector3 = site.pose.origin
		var key := "%d:%d:%s"%[floori(at.x/224),floori(at.z/224),site.kind]
		if not buckets.has(key): buckets[key] = {"kind":site.kind,"sites":[]}
		buckets[key].sites.append(site)
	var parent := Node3D.new()
	parent.name = "ExpansionRoadsideLife"
	parent.set_meta("sites",world.decor_sites.duplicate(true))
	world.add_child(parent)
	var surface := ShaderMaterial.new()
	surface.shader = load("res://assets/exported/shaders/set_piece_motion.gdshader")
	surface.set_shader_parameter("glow",.04 if float(world.art.emission)>0 or world.art.space else 0.0)
	for key: String in buckets:
		var bucket: Dictionary = buckets[key]
		var source: ArrayMesh = ExpansionLifeProps.mesh(str(bucket.kind))
		var arrays := source.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var tool := ExpansionSetPieces.tool()
		for site: Dictionary in bucket.sites:
			for i in range(vertices.size()):
				var point: Vector3 = site.pose*vertices[i]
				if vertices[i].y<-.1:
					var terrain := CourseArt.height_from_grid(world.terrain_grid,point,point.y)
					point.y = minf(point.y,terrain-.2)
				tool.set_color(colors[i])
				tool.set_normal(site.pose.basis*normals[i])
				tool.add_vertex(point)
		var node := MeshInstance3D.new()
		node.name = "Life_"+key.replace(":","_")
		node.mesh = tool.commit()
		node.material_override = surface
		node.set_meta("kind",bucket.kind)
		node.set_meta("site_count",bucket.sites.size())
		node.set_meta("lod_limit",180.0)
		node.add_to_group("scenery_distance")
		node.visibility_range_end = 180
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)
