shader_type spatial;
render_mode cull_disabled;
varying vec2 world_xz;
uniform vec4 sea_color : source_color = vec4(0.1922,0.7490,0.7569,1.0);
uniform vec4 horizon_color : source_color = vec4(0.7255,0.9020,0.9294,1.0);
void vertex() { world_xz = (MODEL_MATRIX * vec4(VERTEX,1.0)).xz; }
void fragment() {
	vec2 first = vec2(sin(world_xz.x*0.07+TIME*0.3),cos(world_xz.y*0.06+TIME*0.24));
	vec2 second = vec2(cos((world_xz.x+world_xz.y)*0.13-TIME*0.4),sin((world_xz.x-world_xz.y)*0.11+TIME*0.33));
	NORMAL_MAP = normalize(vec3((first+second)*0.07,1.0))*0.5+0.5;
	float reflection = pow(1.0-clamp(dot(NORMAL,VIEW),0.0,1.0),3.0);
	ALBEDO = mix(sea_color.rgb,horizon_color.rgb,reflection*0.55);
	ROUGHNESS = 0.36;
	SPECULAR = 0.45;
}
