shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled;
uniform float opacity : hint_range(0.0,1.0) = 1.0;
void fragment() {
	float radius = length((UV - vec2(0.5)) * 2.0);
	ALBEDO = vec3(0.09, 0.16, 0.22);
	ALPHA = (1.0 - smoothstep(0.45, 1.0, radius)) * 0.3 * opacity;
}
