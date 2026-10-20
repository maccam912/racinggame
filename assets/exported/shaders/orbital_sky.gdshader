shader_type sky;
render_mode use_half_res_pass;
float star_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void sky() {
    vec3 ray = normalize(EYEDIR);
    vec2 uv = vec2(atan(ray.x,ray.z),asin(clamp(ray.y,-1.0,1.0)));
    vec3 backdrop = mix(vec3(0.045,0.012,0.10),vec3(0.008,0.006,0.035),smoothstep(0.0,0.8,ray.y));
    float nebula = pow(max(0.0,1.0-abs(ray.y-0.23-sin(uv.x*2.1)*0.1)*4.0),3.0);
    backdrop += vec3(0.065,0.014,0.10)*nebula;
    vec2 cell = floor(uv*260.0);
    float seed = star_hash(cell);
    float star = step(0.991,seed)*(1.0-smoothstep(0.03,0.24,length(fract(uv*260.0)-0.5)));
    backdrop += vec3(0.67,0.83,1.0)*star;
    vec3 center = normalize(vec3(-0.55,0.42,-0.85));
    vec3 axis = normalize(cross(center,vec3(0.0,1.0,0.0)));
    vec3 up = cross(axis,center);
    vec2 p = vec2(dot(ray,axis),dot(ray,up));
    float radius = length(p);
    float facing = step(0.0,dot(ray,center));
    float rings = (1.0-smoothstep(0.012,0.022,abs(length(p/vec2(0.44,0.095))-1.0)))*facing;
    backdrop = mix(backdrop,vec3(0.47,0.66,0.86),rings*0.85);
    float disc = (1.0-smoothstep(0.202,0.205,radius))*facing;
    float lighting = clamp(0.50-p.x*2.0+p.y,0.14,1.0);
    float bands = sin(p.y*145.0+sin(p.x*22.0)*1.1)*0.04;
    vec3 planet = (mix(vec3(0.35,0.17,0.56),vec3(0.70,0.40,0.65),p.y*2.0+0.5)+bands)*lighting;
    COLOR = mix(backdrop,planet,disc);
}
