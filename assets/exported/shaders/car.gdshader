shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
#include "res://assets/exported/shaders/car_surface.gdshaderinc"
void fragment() {
	vec3 color;
	vec3 glow;
	float roughness;
	float metal;
	vec3 reflected_world = (INV_VIEW_MATRIX*vec4(reflect(-normalize(VIEW),normalize(NORMAL)),0.0)).xyz;
	car_surface(UV, COLOR, NORMAL, VIEW, reflected_world, color, roughness, metal, glow);
	ALBEDO = color;
	ROUGHNESS = roughness;
	METALLIC = metal;
	EMISSION = glow;
}
