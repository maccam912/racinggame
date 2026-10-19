shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back;
#include "res://assets/exported/shaders/car_surface.gdshaderinc"
uniform float visual_alpha : hint_range(0.0,1.0) = 0.75;
void fragment() {
	if (visual_alpha<0.001) discard;
	vec3 color;
	vec3 glow;
	float roughness;
	float metal;
	car_surface(UV,COLOR,color,roughness,metal,glow);
	ALBEDO = color;
	ROUGHNESS = roughness;
	METALLIC = metal;
	EMISSION = glow;
	ALPHA = visual_alpha;
}
