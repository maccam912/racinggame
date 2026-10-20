uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 paint : source_color = vec4(0.945, 0.42, 0.314, 1.0);
uniform vec4 stripe : source_color = vec4(0.96, 0.922, 0.827, 1.0);
uniform float braking : hint_range(0.0, 1.0) = 0.0;
varying vec3 car_position;
varying vec3 car_normal;
void vertex() {
	car_position = VERTEX;
	car_normal = NORMAL;
}
float paint_hash(vec3 p) {
	p = fract(p*vec3(0.1031,0.1030,0.0973));
	p += dot(p,p.yxz+33.33);
	return fract((p.x+p.y)*p.z);
}
float paint_dither(vec2 p) {
	ivec2 cell = ivec2(mod(floor(p),4.0));
	const mat4 threshold = mat4(vec4(0.0,12.0,3.0,15.0),vec4(8.0,4.0,11.0,7.0),vec4(2.0,14.0,1.0,13.0),vec4(10.0,6.0,9.0,5.0));
	return (threshold[cell.x][cell.y]+0.5)/16.0;
}
void car_surface(vec2 uv, vec4 role, vec3 view_normal, vec3 view_direction, vec3 reflected_world, out vec3 color, out float roughness, out float metal, out vec3 glow) {
	color = texture(atlas, uv).rgb;
	if (role.r > 0.5) color *= paint.rgb;
	if (role.g > 0.5) color *= stripe.rgb;
	roughness = role.a < 0.15 ? 0.9 : role.a < 0.25 ? 0.25 : 0.34;
	metal = role.r > 0.5 || role.g > 0.5 ? 0.3 : role.a > 0.35 && role.a < 0.45 ? 0.5 : 0.0;
	// Static object-space ink and flakes: they travel with the car. Fade
	// subpixel detail with derivatives instead of sparkling at a distance.
	vec2 plane = abs(car_normal.y)>0.65 ? car_position.xz : abs(car_normal.z)>0.65 ? car_position.xy : car_position.zy;
	float detail = 1.0-smoothstep(0.5,1.8,length(fwidth(plane*80.0)));
	float grain = paint_hash(floor(car_position*80.0));
	float rim = pow(1.0-clamp(dot(normalize(view_normal),normalize(view_direction)),0.0,1.0),2.0);
	float sky = smoothstep(-0.12,0.4,reflected_world.y);
	float horizon = 1.0-smoothstep(0.035,0.19,abs(reflected_world.y-0.02));
	vec3 reflection = mix(vec3(0.35,0.19,0.11),vec3(0.15,0.46,0.72),sky);
	if (role.r>0.5 || role.g>0.5) {
		float ink = paint_dither(plane*80.0);
		color = mix(color,floor(color*28.0+ink)/28.0,detail*0.65);
		color *= 0.97+(grain-0.5)*0.075*detail;
		color += reflection*(0.035+rim*0.24)+vec3(0.75,0.88,1.0)*horizon*0.14;
		color += vec3(0.035)*step(0.955,grain)*detail;
		roughness = 0.27+(0.5-grain)*0.075*detail;
		metal = role.r>0.5 ? 0.4 : 0.3;
	} else if (role.a<0.15) {
		color *= 0.95+grain*detail*0.08;
		roughness = 0.94;
	} else if (role.a<0.25) {
		color = mix(color,reflection,0.27+rim*0.3)+vec3(0.35,0.65,0.8)*horizon*0.1;
		float sweep = abs(fract(plane.x*0.4+plane.y*0.55+0.17)-0.52);
		color += vec3(0.045,0.14,0.2)*(1.0-smoothstep(0.08,0.23,sweep));
		color += vec3(0.06,0.15,0.21)*(1.0-smoothstep(0.015,0.06,sweep));
		roughness = 0.16;
		metal = 0.25;
	} else if (role.a>0.35 && role.a<0.45) {
		color = mix(color,reflection,0.3)+vec3(0.35)*horizon;
		roughness = 0.18;
		metal = 0.75;
	}
	glow = vec3(0.0);
	if (role.b > 0.5) {
		color = mix(color, vec3(1.0, 0.13, 0.06), braking);
		glow = color * (0.06 + braking * 0.65);
	}
	if (role.a > 0.25 && role.a < 0.35) glow = color * 0.16;
}
