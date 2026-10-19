shader_type spatial;
render_mode cull_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic;
uniform float window_glow = 0.0;
void fragment() {
	vec3 base = texture(atlas, UV).rgb;
	ALBEDO = base;
	ROUGHNESS = 0.9;
	vec2 tile = floor(UV * 4.0);
	float window_mask = step(2.5, tile.x) * step(1.5, tile.y) * (1.0-step(2.5,tile.y)) * step(0.65,base.r);
	EMISSION = base * window_glow * window_mask;
}
