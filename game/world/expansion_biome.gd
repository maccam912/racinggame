class_name ExpansionBiome
extends RefCounted
## Cosmetic world-space ground treatments; road grip and geometry are unchanged.
const SPACE_VIEWS := {"lunar_freight":1,"orbital_gardens":2,"crystal_chasm":3,"mars_badlands":4,"reactor_rift":5}
# Road, paint and rail colors follow the place rather than one space preset.
const SPACE_ROADS := {
	"lunar_freight":["444950","EEE5B7","A2ACB5"],
	"orbital_gardens":["314B4B","A8F1CC","93BBB2"],
	"crystal_chasm":["40394F","E0B5F4","AFA0CA"],
	"mars_badlands":["51433E","FFE2A0","C5A689"],
	"reactor_rift":["303F46","D1F0A3","8DAAA1"]
}
const STYLES := {
	"glacier_ridge":[1,"7EA8BA"],"aurora_harbor":[1,"8CB9C5"],
	"alpine_meadow":[0,"A6AC71"],"frostbite_fjord":[1,"6DACC1"],"tundra_pipeline":[0,"78866A"],
	"rainforest_ruins":[9,"655543"],"monsoon_delta":[9,"827157"],
	"coral_causeway":[2,"C5BDA6"],"mangrove_maze":[9,"655F43"],"cloudforest_climb":[0,"719C80"],
	"sakura_ring":[0,"A1A47A"],"bamboo_gorge":[0,"466E62"],"lantern_market":[3,"A48478"],
	"terrace_touge":[0,"91A865"],"temple_coast":[0,"A8AC7F"],
	"saltflat_velocity":[4,"AFAD9F"],"dune_serpent":[2,"D2B18B"],"oasis_citadel":[2,"D5C197"],
	"copper_mesa":[7,"D99A70"],"storm_chase":[2,"A59578"],
	"steelworks_sprint":[3,"8B918B"],"container_corkscrew":[3,"888D97"],"neon_underpass":[3,"62637E"],
	"windfarm_run":[0,"A8A16F"],"festival_speedway":[3,"88829A"],
	"lunar_freight":[5,"70777F"],"orbital_gardens":[0,"85A39B"],"crystal_chasm":[6,"86CAE3"],
	"mars_badlands":[7,"D29466"],"reactor_rift":[8,"72C9A9"]
}

static func material(id: String) -> ShaderMaterial:
	var key := "biome_"+id
	if CourseArt.materials.has(key): return CourseArt.materials[key]
	var art := CourseArt.spec(id)
	var spec: Array = STYLES[id]
	var surface := ShaderMaterial.new()
	surface.shader = load("res://assets/exported/shaders/biome_ground.gdshader")
	surface.set_shader_parameter("ground_color",Color.html(art.ground))
	surface.set_shader_parameter("accent_color",Color.html(str(spec[1])))
	surface.set_shader_parameter("biome",int(spec[0]))
	surface.set_shader_parameter("course_seed",float(art.sky_seed))
	CourseArt.materials[key] = surface
	return surface
