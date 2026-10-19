shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
#include "res://assets/exported/shaders/car_surface.gdshaderinc"
void fragment() {
	vec3 color;
	vec3 glow;
	float roughness;
	float metal;
	car_surface(UV, COLOR, color, roughness, metal, glow);
	ALBEDO = color;
	ROUGHNESS = roughness;
	METALLIC = metal;
	EMISSION = glow;
}
