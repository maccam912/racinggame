shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
uniform vec4 paving_color : source_color = vec4(0.32,0.35,0.41,1.0);
uniform float lane_wear : hint_range(0.0,0.3) = 0.13;
varying vec3 paving_position;
void vertex() {
	paving_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
float stone_hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx)*0.1031);
	q += dot(q,q.yzx+33.33);
	return fract((q.x+q.y)*q.z);
}
float paving_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 weight = fract(p);
	weight = weight*weight*(3.0-2.0*weight);
	return mix(mix(stone_hash(cell),stone_hash(cell+vec2(1.0,0.0)),weight.x),mix(stone_hash(cell+vec2(0.0,1.0)),stone_hash(cell+vec2(1.0)),weight.x),weight.y);
}
void fragment() {
	vec2 p = paving_position.xz;
	float detail = 1.0-smoothstep(0.7,2.0,length(fwidth(p*26.0)));
	float aggregate = stone_hash(floor(p*26.0));
	float patches = paving_noise(p*0.19);
	float fine = (floor(aggregate*5.0)/4.0-0.5)*detail;
	// Route UVs are metres along the road and normalized lateral distance.
	// Four broad tire paths stay inside the cream road-edge markings.
	float side = abs(UV.y);
	float tracks = 1.0-smoothstep(0.025,0.095,min(abs(side-0.28),abs(side-0.62)));
	float wear = tracks*lane_wear*(0.55+0.45*paving_noise(vec2(UV.x*0.055,side*3.0)));
	vec3 base = paving_color.rgb*(0.87+patches*0.21-wear);
	base += vec3(0.033,0.036,0.04)*fine;
	base += vec3(0.015,0.013,0.01)*step(0.93,aggregate)*detail;
	ALBEDO = clamp(base,vec3(0.015),vec3(0.8));
	ROUGHNESS = 0.94;
	SPECULAR = 0.22;
}
