shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform bool spark = false;
void fragment() {
	vec2 p = (UV-vec2(0.5))*2.0;
	float radius = length(p);
	float soft = 1.0-smoothstep(0.2,1.0,radius);
	if (spark) soft = (1.0-smoothstep(0.0,0.25,abs(p.x)))*(1.0-smoothstep(0.25,1.0,abs(p.y)));
	ALBEDO = COLOR.rgb;
	EMISSION = spark ? COLOR.rgb*0.35 : vec3(0.0);
	ALPHA = COLOR.a*soft;
}
