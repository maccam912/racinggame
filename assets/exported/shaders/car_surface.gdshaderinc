uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 paint : source_color = vec4(0.945, 0.42, 0.314, 1.0);
uniform vec4 stripe : source_color = vec4(0.96, 0.922, 0.827, 1.0);
uniform float braking : hint_range(0.0, 1.0) = 0.0;
void car_surface(vec2 uv, vec4 role, out vec3 color, out float roughness, out float metal, out vec3 glow) {
	color = texture(atlas, uv).rgb;
	if (role.r > 0.5) color *= paint.rgb;
	if (role.g > 0.5) color *= stripe.rgb;
	roughness = role.a < 0.15 ? 0.9 : role.a < 0.25 ? 0.25 : 0.34;
	metal = role.r > 0.5 || role.g > 0.5 ? 0.3 : role.a > 0.35 && role.a < 0.45 ? 0.5 : 0.0;
	glow = vec3(0.0);
	if (role.b > 0.5) {
		color = mix(color, vec3(1.0, 0.13, 0.06), braking);
		glow = color * (0.06 + braking * 0.65);
	}
	if (role.a > 0.25 && role.a < 0.35) glow = color * 0.16;
}
