shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
void fragment() {
	float edge = smoothstep(0.0,0.15,UV.x)*(1.0-smoothstep(0.85,1.0,UV.x));
	ALBEDO = vec3(0.10,0.13,0.15);
	ALPHA = COLOR.a*edge;
}
